import AppKit
import IliadboxKit
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications

private func appString(_ key: String, _ arguments: CVarArg...) -> String {
  String(format: NSLocalizedString(key, comment: "IliadBar status"), arguments: arguments)
}

struct Crumb: Identifiable, Equatable {
  let name: String
  let pathB64: String
  var id: String { pathB64 }
}

enum BoxAvailability: Equatable {
  case unconfigured
  case connecting
  case online(updatedAt: Date)
  case stale(updatedAt: Date, message: String)
  case offline(message: String)

  var label: String {
    switch self {
    case .unconfigured: NSLocalizedString("nessuna box", comment: "Box availability")
    case .connecting: NSLocalizedString("connessione…", comment: "Box availability")
    case .online: NSLocalizedString("online", comment: "Box availability")
    case .stale: NSLocalizedString("dati non aggiornati", comment: "Box availability")
    case .offline: NSLocalizedString("offline", comment: "Box availability")
    }
  }

  var isOnline: Bool {
    if case .online = self { return true }
    return false
  }
}

enum AdvancedModule: String, CaseIterable, Hashable {
  case nat, incomingPorts, samba, ftp, upnpIGD, upnpAV, remoteAccess, parental, calls, contacts,
    pvr, vpn, vpnServer
}

@MainActor
final class AppModel: ObservableObject {
  // Download
  @Published var tasks: [DownloadTask] = []
  @Published var downloadStats: DownloadStats?
  @Published var detailTask: DownloadTask?
  @Published var detailFiles: [DownloadFile] = []
  @Published var detailTrackers: [DownloadTracker] = []
  @Published var detailPeers: [DownloadPeer] = []
  @Published var detailPieces: String?
  @Published var detailLoading = false
  // Box (tab stats)
  @Published var connection: ConnectionStatus?
  @Published var system: SystemInfo?
  // File (tab browser)
  @Published var entries: [FsEntry] = []
  @Published var crumbs: [Crumb] = []
  @Published var filesLoading = false
  @Published var storageDisks: [StorageDisk] = []
  @Published var shareLinks: [ShareLink] = []
  @Published var fileOperationStatus: String?
  @Published var uploadProgress: Double?
  @Published private(set) var fileOperationCanCancel = false
  // Rete locale
  @Published var lanInterfaces: [LanInterface] = []
  @Published var lanHosts: [LanHost] = []
  @Published var dhcpLeases: [DhcpStaticLease] = []
  @Published var dhcpConfig: DhcpConfig?
  @Published var wifiConfig: WifiGlobalConfig?
  @Published var wifiAccessPoints: [WifiAccessPoint] = []
  @Published var wifiBSSs: [WifiBSS] = []
  @Published var wifiStations: [WifiStation] = []
  @Published var networkLoading = false
  @Published var networkSettingsAllowed = false
  // Servizi avanzati
  @Published var portForwardingRules: [PortForwardingRule] = []
  @Published var incomingPorts: [IncomingPort] = []
  @Published var sambaConfig: SambaConfig?
  @Published var ftpConfig: FTPConfig?
  @Published var upnpIGDConfig: UPnPIGDConfig?
  @Published var upnpAVConfig: UPnPAVConfig?
  @Published var connectionConfiguration: ConnectionConfiguration?
  @Published var parentalRules: [ParentalRule] = []
  @Published var callLog: [CallEntry] = []
  @Published var contacts: [ContactEntry] = []
  @Published var pvrRecords: [PVRProgrammedRecord] = []
  @Published var vpnClientStatus: VPNClientStatus?
  @Published var vpnServers: [VPNServer] = []
  @Published var selectedParentalPlanning: ParentalPlanning?
  @Published var advancedCapabilities: Set<AdvancedModule> = []
  @Published var advancedLoading = false
  @Published var parentalControlAllowed = false
  // Stato generale
  @Published var paired: Bool
  @Published var pairingInProgress = false
  @Published var credentialActivationInProgress = false
  /// Feedback transiente (ultimo esito / errore), mostrato sotto l'header.
  @Published var statusLine: String?
  @Published var launchAtLogin: Bool
  @Published var profiles: [BoxProfile]
  @Published var activeProfileID: String?
  @Published var preferences: AppPreferences
  @Published var discoveredBoxes: [DiscoveredBox] = []
  @Published var discoveryState: DiscoveryState = .idle
  @Published var availability: BoxAvailability
  @Published var liveEventsConnected = false

  private var client: IliadboxClient
  private let discovery = IliadboxDiscovery()
  private var pollTask: Task<Void, Never>?
  private var eventTask: Task<Void, Never>?
  private var previousTaskStatuses: [Int: String] = [:]
  private var hasLoadedTasks = false
  private var hostInterfaces: [String: String] = [:]
  private var currentFilesystemTaskID: Int?

  init() {
    let appConfig = ConfigStore.loadAppConfig()
    let profile = appConfig.activeBox
    let config = IbxConfig(
      boxID: profile?.id ?? BoxProfile.legacyID,
      baseURL: profile?.baseURL ?? BoxProfile.defaultBaseURL,
      appToken: profile?.appToken
    )
    client = IliadboxClient(config: config)
    paired = config.appToken != nil
    profiles = appConfig.boxes
    activeProfileID = appConfig.activeBox?.id
    preferences = appConfig.preferences
    availability = appConfig.activeBox == nil ? .unconfigured : .connecting
    launchAtLogin = Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled
    startDiscovery()
  }

  /// The status item must exist before macOS is allowed to present a Keychain
  /// authorization dialog. Reading synchronously from `init` can otherwise
  /// block `applicationDidFinishLaunching` and leave a live but invisible app.
  func activateSavedCredential() async {
    guard !credentialActivationInProgress else { return }
    credentialActivationInProgress = true
    defer { credentialActivationInProgress = false }
    let appConfig = ConfigStore.loadAppConfig()
    guard let profile = appConfig.activeBox else {
      statusLine = appString("Nessuna iliadbox configurata")
      return
    }
    var token = profile.appToken
    if token == nil {
      // One-time migration for installations that previously stored the token
      // in Keychain. The old item is deliberately left recoverable.
      let credential = await Task.detached(priority: .userInitiated) {
        do {
          return (try KeychainTokenStore.read(profileID: profile.id), nil as String?)
        } catch {
          return (nil, error.localizedDescription)
        }
      }.value
      if let message = credential.1 {
        NSLog("IliadBar credential migration failed: %@", message)
        statusLine = message
        return
      }
      token = credential.0
    }
    guard let token else {
      statusLine = appString("Nessuna credenziale salvata")
      return
    }
    let config = IbxConfig(boxID: profile.id, baseURL: profile.baseURL, appToken: token)
    if profile.appToken == nil {
      do {
        try ConfigStore.save(config)
        profiles = ConfigStore.loadAppConfig().boxes
      } catch {
        statusLine = error.localizedDescription
        return
      }
    }
    client = IliadboxClient(config: config)
    paired = true
    availability = .connecting
    statusLine = nil
    requestNotificationPermission()
    startPolling()
  }

  // MARK: Stato derivato

  var activeTasks: [DownloadTask] {
    tasks.filter { isActive($0) }
  }

  /// Percentuale aggregata mostrata accanto all'icona in menu bar:
  /// visibile solo quando c'è almeno un download attivo.
  var menuBarPercent: String? {
    let downloading = activeTasks.filter { ($0.size ?? 0) > 0 }
    guard !downloading.isEmpty else { return nil }
    let total = downloading.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
    let received = downloading.reduce(Int64(0)) { $0 + ($1.rxBytes ?? 0) }
    guard total > 0 else { return nil }
    return "\(Int(Double(received) / Double(total) * 100))%"
  }

  // MARK: Polling download

  /// Cadenza adattiva: serrata coi download attivi, rilassata a riposo.
  func startPolling() {
    pollTask?.cancel()
    startLiveEvents()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        let rawSeconds =
          (self?.activeTasks.isEmpty == false)
          ? self?.preferences.activeRefreshSeconds
          : self?.preferences.idleRefreshSeconds
        let seconds = UInt64(max(1, rawSeconds ?? 20))
        try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
      }
    }
  }

  private func startLiveEvents() {
    eventTask?.cancel()
    eventTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        do {
          let stream = try await self.client.eventMessages(events: [
            "lan_host_l3addr_reachable",
            "lan_host_l3addr_unreachable",
          ])
          for try await message in stream {
            self.liveEventsConnected = true
            if message.action == "notification", message.event?.hasPrefix("lan_host_") == true {
              await self.refreshNetwork()
            }
          }
        } catch {
          self.liveEventsConnected = false
        }
        if !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
      }
    }
  }

  func refresh() async {
    guard paired else { return }
    do {
      async let listCall = client.listDownloads()
      async let statsCall = try? client.downloadStats()
      let (list, stats) = try await (listCall, statsCall)
      processDownloadTransitions(list)
      // Attivi in testa, poi i più recenti.
      tasks = list.sorted { lhs, rhs in
        let la = isActive(lhs)
        let ra = isActive(rhs)
        if la != ra { return la }
        return lhs.id > rhs.id
      }
      downloadStats = stats
      availability = .online(updatedAt: Date())
      saveWidgetSnapshot()
      if statusLine == appString("iliadbox non raggiungibile") { statusLine = nil }
    } catch {
      recordFailure(error)
    }
  }

  private func isActive(_ task: DownloadTask) -> Bool {
    ["downloading", "starting", "checking", "retry", "queued"].contains(task.status ?? "")
  }

  // MARK: Azioni download

  func add(magnet: String) async {
    await addURL(magnet)
  }

  func addURL(_ url: String) async {
    guard paired else {
      statusLine = appString("Prima associa IliadBar alla iliadbox")
      return
    }
    do {
      let id = try await client.addDownload(url: url)
      let name = (try? await client.download(id: id))?.name ?? displayName(forMagnet: url)
      // The direct feedback below owns this start notification. Seeding the
      // baseline prevents the following refresh from emitting it a second time.
      previousTaskStatuses[id] = "starting"
      statusLine = nil
      notifyDownloadEvent(.started, title: appString("Download avviato sulla iliadbox"), body: name)
      await refresh()
    } catch {
      statusLine = error.localizedDescription
      notifyDownloadEvent(
        .failed, title: appString("Errore download"), body: error.localizedDescription)
    }
  }

  func addFromPasteboard() async {
    guard
      let text = NSPasteboard.general.string(forType: .string)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      text.hasPrefix("magnet:")
    else {
      statusLine = appString("Negli appunti non c'è un link magnet")
      return
    }
    await add(magnet: text)
  }

  func chooseAndAddDownloadFile() async {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [
      .init(filenameExtension: "torrent")!, .init(filenameExtension: "nzb")!,
    ]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      statusLine = appString("Aggiungo %@…", url.lastPathComponent)
      let data = try Data(contentsOf: url)
      _ = try await client.addDownloadFile(data: data, filename: url.lastPathComponent)
      statusLine = nil
      await refresh()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func togglePause(_ task: DownloadTask) async {
    do {
      if task.status == "stopped" {
        try await client.resumeDownload(id: task.id)
      } else {
        try await client.pauseDownload(id: task.id)
      }
      await refresh()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  /// Rimuove solo il task: i file scaricati restano sulla box.
  func remove(_ task: DownloadTask, eraseFiles: Bool = false) async {
    do {
      try await client.deleteDownload(id: task.id, eraseFiles: eraseFiles)
      if detailTask?.id == task.id {
        detailTask = nil
        detailFiles = []
        detailTrackers = []
        detailPeers = []
        detailPieces = nil
      }
      await refresh()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func retry(_ task: DownloadTask) async {
    do {
      _ = try await client.retryDownload(id: task.id)
      await refresh()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func setPriority(_ priority: String, for task: DownloadTask) async {
    do {
      detailTask = try await client.setDownloadPriority(id: task.id, priority: priority)
      await refresh()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func loadDownloadDetails(_ task: DownloadTask) async {
    detailTask = task
    detailLoading = true
    defer { detailLoading = false }
    async let taskCall = try? client.download(id: task.id)
    async let filesCall = try? client.downloadFiles(id: task.id)
    async let trackersCall = task.type == "bt" ? (try? client.downloadTrackers(id: task.id)) : nil
    async let peersCall = task.type == "bt" ? (try? client.downloadPeers(id: task.id)) : nil
    async let piecesCall = task.type == "bt" ? (try? client.downloadPieces(id: task.id)) : nil
    let (freshTask, files, trackers, peers, pieces) = await (
      taskCall, filesCall, trackersCall, peersCall, piecesCall
    )
    if let freshTask { detailTask = freshTask }
    detailFiles = files ?? []
    detailTrackers = trackers ?? []
    detailPeers = peers ?? []
    detailPieces = pieces
  }

  func setFilePriority(_ priority: String, file: DownloadFile) async {
    guard let task = detailTask else { return }
    do {
      try await client.setDownloadFilePriority(taskID: task.id, fileID: file.id, priority: priority)
      await loadDownloadDetails(task)
    } catch {
      statusLine = error.localizedDescription
    }
  }

  // MARK: Box stats

  func refreshBoxStats() async {
    guard paired else { return }
    async let connectionCall = try? client.connectionStatus()
    async let systemCall = try? client.systemInfo()
    let (conn, sys) = await (connectionCall, systemCall)
    if let conn { connection = conn }
    if let sys { system = sys }
    if conn != nil || sys != nil {
      availability = .online(updatedAt: Date())
      saveWidgetSnapshot()
    } else {
      recordFailure(FbxError.invalidResponse)
    }
  }

  // MARK: File browser

  /// Primo ingresso: parte dalla radice per mostrare tutti i volumi montati.
  func openFilesRootIfNeeded() async {
    guard paired else { return }
    if let current = crumbs.last {
      await loadEntries(pathB64: current.pathB64)
      return
    }
    filesLoading = true
    defer { filesLoading = false }
    let rootB64 = IliadboxClient.rootPathB64
    crumbs = [Crumb(name: "Archivi", pathB64: rootB64)]
    await loadEntries(pathB64: rootB64)
  }

  func enter(_ entry: FsEntry) async {
    guard entry.isDirectory else { return }
    crumbs.append(Crumb(name: entry.name, pathB64: entry.path))
    await loadEntries(pathB64: entry.path)
  }

  func goBack() async {
    guard crumbs.count > 1 else { return }
    crumbs.removeLast()
    if let current = crumbs.last {
      await loadEntries(pathB64: current.pathB64)
    }
  }

  func reloadFiles() async {
    if let current = crumbs.last {
      await loadEntries(pathB64: current.pathB64)
    }
  }

  private func loadEntries(pathB64: String) async {
    filesLoading = true
    defer { filesLoading = false }
    do {
      let list = try await client.listFolder(pathB64: pathB64)
      entries = list.sorted { lhs, rhs in
        if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func listFolderForPicker(pathB64: String) async -> [FsEntry] {
    (try? await client.listFolder(pathB64: pathB64))?
      .filter(\.isDirectory)
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
  }

  func createFolder(named name: String) async {
    guard let parent = crumbs.last?.pathB64 else { return }
    do {
      try await client.createDirectory(parentB64: parent, name: name)
      await reloadFiles()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func rename(_ entry: FsEntry, to name: String) async {
    do {
      _ = try await client.rename(pathB64: entry.path, to: name)
      await reloadFiles()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func removeEntries(_ entries: [FsEntry]) async {
    guard !entries.isEmpty else { return }
    do {
      let task = try await client.remove(pathsB64: entries.map(\.path))
      fileOperationStatus = appString("Eliminazione avviata · task %@", task.id)
      await waitForFilesystemTask(task.id)
      await reloadFiles()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func transferEntries(
    _ entries: [FsEntry],
    to destinationB64: String,
    move: Bool,
    conflictMode: FileConflictMode
  ) async {
    guard !entries.isEmpty else { return }
    do {
      let task =
        if move {
          try await client.move(
            pathsB64: entries.map(\.path), to: destinationB64, mode: conflictMode)
        } else {
          try await client.copy(
            pathsB64: entries.map(\.path), to: destinationB64, mode: conflictMode)
        }
      let operation = move ? appString("Spostamento") : appString("Copia")
      fileOperationStatus = appString("%@ avviato · task %@", operation, task.id)
      await waitForFilesystemTask(task.id)
      await reloadFiles()
    } catch is CancellationError {
      fileOperationStatus = nil
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func createShareLink(for entry: FsEntry) async {
    do {
      let link = try await client.createShareLink(pathB64: entry.path)
      guard let url = link.fullURL, !url.isEmpty else {
        statusLine = appString(
          "Abilita l’accesso remoto sulla iliadbox per creare un link pubblico")
        return
      }
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(url, forType: .string)
      statusLine = appString("Link copiato negli appunti")
      await refreshShareLinks()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func refreshShareLinks() async {
    do {
      shareLinks = try await client.shareLinks()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func revokeShareLink(_ link: ShareLink) async {
    do {
      try await client.deleteShareLink(token: link.token)
      await refreshShareLinks()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func chooseAndUploadFiles(conflictMode: UploadConflictMode = .missing) async {
    guard let destination = crumbs.last?.pathB64 else { return }
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK else { return }
    fileOperationCanCancel = true
    defer {
      uploadProgress = nil
      fileOperationStatus = nil
      fileOperationCanCancel = false
    }
    for url in panel.urls {
      do {
        try Task.checkCancellation()
        fileOperationStatus = appString("Carico %@…", url.lastPathComponent)
        uploadProgress = 0
        try await client.uploadFile(
          at: url,
          filename: url.lastPathComponent,
          destinationB64: destination,
          conflictMode: conflictMode
        ) { [weak self] uploaded, total in
          Task { @MainActor in
            self?.uploadProgress = total > 0 ? Double(uploaded) / Double(total) : nil
          }
        }
      } catch is CancellationError {
        statusLine = NSLocalizedString("Caricamento annullato", comment: "Upload cancellation")
        break
      } catch {
        statusLine = appString("%@: %@", url.lastPathComponent, error.localizedDescription)
        break
      }
    }
    await reloadFiles()
  }

  func cancelFileOperation() async {
    fileOperationCanCancel = false
    if let id = currentFilesystemTaskID {
      do {
        try await client.cancelFilesystemTask(id: id)
      } catch {
        statusLine = error.localizedDescription
      }
    }
    currentFilesystemTaskID = nil
    uploadProgress = nil
    fileOperationStatus = nil
  }

  func refreshStorage() async {
    storageDisks = (try? await client.storageDisks()) ?? []
  }

  // MARK: Rete locale

  func refreshNetwork() async {
    guard paired else { return }
    networkLoading = true
    defer { networkLoading = false }
    do {
      let interfaces = try await client.lanInterfaces()
      lanInterfaces = interfaces

      var hosts: [LanHost] = []
      var interfacesByHost: [String: String] = [:]
      for interface in interfaces {
        let interfaceHosts = (try? await client.lanHosts(interface: interface.name)) ?? []
        hosts.append(contentsOf: interfaceHosts)
        for host in interfaceHosts { interfacesByHost[host.id] = interface.name }
      }
      hostInterfaces = interfacesByHost
      lanHosts = Dictionary(grouping: hosts, by: \.id)
        .compactMap { $0.value.first }
        .sorted {
          if ($0.reachable == true) != ($1.reachable == true) { return $0.reachable == true }
          return $0.primaryName.localizedCaseInsensitiveCompare($1.primaryName) == .orderedAscending
        }

      async let leasesCall = try? client.dhcpStaticLeases()
      async let dhcpConfigCall = try? client.dhcpConfig()
      async let configCall = try? client.wifiGlobalConfig()
      async let accessPointsCall = try? client.wifiAccessPoints()
      async let bssCall = try? client.wifiBSSList()
      let (leases, dhcp, config, accessPoints, bss) = await (
        leasesCall, dhcpConfigCall, configCall, accessPointsCall, bssCall
      )
      dhcpLeases = leases ?? []
      dhcpConfig = dhcp
      wifiConfig = config
      wifiAccessPoints = accessPoints ?? []
      wifiBSSs = bss ?? []

      var stations: [WifiStation] = []
      for accessPoint in wifiAccessPoints {
        stations.append(
          contentsOf: (try? await client.wifiStations(accessPointID: accessPoint.id)) ?? [])
      }
      wifiStations = stations
      networkSettingsAllowed = await client.hasPermission("settings")
      availability = .online(updatedAt: Date())
    } catch {
      recordFailure(error)
    }
  }

  func renameLanHost(_ host: LanHost, to name: String) async {
    guard networkSettingsAllowed else {
      statusLine = appString("Il permesso Impostazioni non è concesso a IliadBar")
      return
    }
    guard let interface = hostInterfaces[host.id] else { return }
    do {
      _ = try await client.updateLanHost(interface: interface, id: host.id, name: name)
      await refreshNetwork()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func interfaceName(for host: LanHost) -> String? { hostInterfaces[host.id] }

  func setWifiEnabled(_ enabled: Bool) async {
    guard networkSettingsAllowed else {
      statusLine = appString("Il permesso Impostazioni non è concesso a IliadBar")
      return
    }
    do {
      wifiConfig = try await client.setWifiEnabled(enabled)
      await refreshNetwork()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func setWifiBSSEnabled(_ bss: WifiBSS, enabled: Bool) async {
    guard networkSettingsAllowed else { return }
    do {
      _ = try await client.setWifiBSSEnabled(id: bss.id, enabled: enabled)
      await refreshNetwork()
    } catch { statusLine = error.localizedDescription }
  }

  func setWifiBSSWPS(_ bss: WifiBSS, enabled: Bool) async {
    guard networkSettingsAllowed, bss.config?.wpsEnabled != nil else { return }
    do {
      _ = try await client.setWifiBSSWPS(id: bss.id, enabled: enabled)
      await refreshNetwork()
    } catch { statusLine = error.localizedDescription }
  }

  func addDhcpLease(ip: String, mac: String) async {
    guard networkSettingsAllowed else {
      statusLine = appString("Il permesso Impostazioni non è concesso a IliadBar")
      return
    }
    guard IliadboxInputValidator.isIPv4Address(ip), IliadboxInputValidator.isMACAddress(mac)
    else {
      statusLine = appString("Inserisci indirizzi IPv4 e MAC validi")
      return
    }
    do {
      _ = try await client.addDhcpStaticLease(ip: ip, mac: mac)
      await refreshNetwork()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func deleteDhcpLease(_ lease: DhcpStaticLease) async {
    guard networkSettingsAllowed else {
      statusLine = appString("Il permesso Impostazioni non è concesso a IliadBar")
      return
    }
    do {
      try await client.deleteDhcpStaticLease(id: lease.id)
      await refreshNetwork()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  // MARK: Servizi avanzati

  func refreshAdvancedServices() async {
    guard paired else { return }
    advancedLoading = true
    defer { advancedLoading = false }

    async let natCall = try? client.portForwardingRules()
    async let incomingCall = try? client.incomingPorts()
    async let sambaCall = try? client.sambaConfig()
    async let ftpCall = try? client.ftpConfig()
    async let igdCall = try? client.upnpIGDConfig()
    async let avCall = try? client.upnpAVConfig()
    async let connectionConfigCall = try? client.connectionConfiguration()
    async let parentalCall = try? client.parentalRules()
    async let callsCall = try? client.callLog()
    async let contactsCall = try? client.contacts()
    async let pvrCall = try? client.pvrProgrammedRecords()
    async let vpnCall = try? client.vpnClientStatus()
    async let vpnServersCall = try? client.vpnServers()
    let (
      nat, incoming, samba, ftp, igd, av, connectionConfig, parental, calls, contactList, pvr, vpn,
      servers
    ) = await (
      natCall, incomingCall, sambaCall, ftpCall, igdCall, avCall, connectionConfigCall,
      parentalCall, callsCall, contactsCall, pvrCall, vpnCall, vpnServersCall
    )

    var capabilities: Set<AdvancedModule> = []
    if let nat {
      portForwardingRules = nat
      capabilities.insert(.nat)
    }
    if let incoming {
      incomingPorts = incoming
      capabilities.insert(.incomingPorts)
    }
    if let samba {
      sambaConfig = samba
      capabilities.insert(.samba)
    }
    if let ftp {
      ftpConfig = ftp
      capabilities.insert(.ftp)
    }
    if let igd {
      upnpIGDConfig = igd
      capabilities.insert(.upnpIGD)
    }
    if let av {
      upnpAVConfig = av
      capabilities.insert(.upnpAV)
    }
    if let connectionConfig {
      connectionConfiguration = connectionConfig
      capabilities.insert(.remoteAccess)
    }
    if let parental {
      parentalRules = parental
      capabilities.insert(.parental)
    }
    if let calls {
      callLog = calls
      capabilities.insert(.calls)
    }
    if let contactList {
      contacts = contactList
      capabilities.insert(.contacts)
    }
    if let pvr {
      pvrRecords = pvr
      capabilities.insert(.pvr)
    }
    if let vpn {
      vpnClientStatus = vpn
      capabilities.insert(.vpn)
    }
    if let servers {
      vpnServers = servers
      capabilities.insert(.vpnServer)
    }
    advancedCapabilities = capabilities
    networkSettingsAllowed = await client.hasPermission("settings")
    parentalControlAllowed = await client.hasPermission("parental")
  }

  func loadParentalPlanning(for rule: ParentalRule) async {
    selectedParentalPlanning = try? await client.parentalPlanning(ruleID: rule.id)
  }

  func saveParentalPlanning(for rule: ParentalRule, mapping: [String]) async {
    guard parentalControlAllowed, let current = selectedParentalPlanning else { return }
    let expectedCount = (7 + (current.customDayRanges?.count ?? 0)) * current.resolution
    guard mapping.count == expectedCount else {
      statusLine = NSLocalizedString(
        "La pianificazione ricevuta dalla box non ha una dimensione valida",
        comment: "Parental planning validation")
      return
    }
    do {
      selectedParentalPlanning = try await client.updateParentalPlanning(
        ruleID: rule.id,
        planning: ParentalPlanning(
          resolution: current.resolution,
          customDayRanges: current.customDayRanges,
          mapping: mapping
        ))
      await refreshAdvancedServices()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func addParentalRule(description: String, macs: [String]) async {
    guard parentalControlAllowed, !macs.isEmpty else { return }
    do {
      _ = try await client.addParentalRule(macs: macs, description: description)
      await refreshAdvancedServices()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func deleteParentalRule(_ rule: ParentalRule) async {
    guard parentalControlAllowed else { return }
    do {
      try await client.deleteParentalRule(id: rule.id)
      await refreshAdvancedServices()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func addPortForwarding(
    protocolName: String, publicPort: Int, lanIP: String, privatePort: Int, comment: String
  ) async {
    guard networkSettingsAllowed else {
      statusLine = appString("Il permesso Impostazioni non è concesso a IliadBar")
      return
    }
    guard IliadboxInputValidator.isIPv4Address(lanIP) else {
      statusLine = appString("Inserisci un indirizzo IPv4 LAN valido")
      return
    }
    if connection == nil { connection = try? await client.connectionStatus() }
    if let range = connection?.assignedPortRange, !range.contains(publicPort) {
      statusLine = appString(
        "La porta pubblica deve essere compresa tra %@ e %@",
        range.lowerBound,
        range.upperBound
      )
      return
    }
    guard (1...65_535).contains(privatePort), (1...65_535).contains(publicPort) else {
      statusLine = appString("Le porte devono essere comprese tra 1 e 65535")
      return
    }
    do {
      _ = try await client.addPortForwardingRule(
        protocolName: protocolName, wanPort: publicPort, lanIP: lanIP,
        lanPort: privatePort, comment: comment
      )
      await refreshAdvancedServices()
    } catch { statusLine = error.localizedDescription }
  }

  func setPortForwardingEnabled(_ rule: PortForwardingRule, enabled: Bool) async {
    guard networkSettingsAllowed else { return }
    do {
      _ = try await client.setPortForwardingRuleEnabled(id: rule.id, enabled: enabled)
      await refreshAdvancedServices()
    } catch { statusLine = error.localizedDescription }
  }

  func deletePortForwarding(_ rule: PortForwardingRule) async {
    guard networkSettingsAllowed else { return }
    do {
      try await client.deletePortForwardingRule(id: rule.id)
      await refreshAdvancedServices()
    } catch { statusLine = error.localizedDescription }
  }

  private func waitForFilesystemTask(_ id: Int) async {
    currentFilesystemTaskID = id
    fileOperationCanCancel = true
    defer {
      if currentFilesystemTaskID == id { currentFilesystemTaskID = nil }
      fileOperationCanCancel = false
    }
    for _ in 0..<120 {
      if Task.isCancelled { return }
      guard let task = try? await client.filesystemTask(id: id) else { return }
      if task.state == "done" {
        fileOperationStatus = nil
        return
      }
      if task.state == "failed" {
        statusLine = appString(
          "Operazione file non riuscita: %@", task.error ?? appString("errore sconosciuto"))
        fileOperationStatus = nil
        return
      }
      if task.state == "cancelled" {
        fileOperationStatus = nil
        statusLine = NSLocalizedString("Operazione file annullata", comment: "File operation")
        return
      }
      fileOperationStatus = appString(
        "%@ · %@%%", task.type ?? appString("Operazione"), task.progress ?? 0)
      try? await Task.sleep(nanoseconds: 500_000_000)
    }
    fileOperationStatus = nil
    statusLine = NSLocalizedString(
      "Operazione file ancora in corso sulla box", comment: "File operation timeout")
  }

  /// Copia un file dalla box in ~/Downloads del Mac.
  func downloadToMac(_ entry: FsEntry) async {
    guard !entry.isDirectory else { return }
    statusLine = appString("Scarico %@ sul Mac…", entry.name)
    do {
      let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
      let destination = try await client.downloadFile(
        pathB64: entry.path,
        toDirectory: downloads,
        suggestedName: entry.name
      )
      statusLine = nil
      notify(title: appString("File copiato sul Mac"), body: destination.lastPathComponent)
    } catch {
      statusLine = error.localizedDescription
    }
  }

  /// Apre la condivisione SMB della box nel Finder.
  func openSMBShare() {
    let host = URL(string: ConfigStore.load().baseURL)?.host ?? "192.168.1.254"
    if let url = URL(string: "smb://\(host)") {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: Pairing (dal pannello)

  func pair() async {
    pairingInProgress = true
    statusLine = appString("Conferma la richiesta sulla iliadbox…")
    defer { pairingInProgress = false }
    do {
      let deviceName = Host.current().localizedName ?? "Mac"
      let auth = try await client.requestAuthorization(deviceName: deviceName)
      try await client.waitForApproval(trackId: auth.trackId)
      var config = ConfigStore.load()
      config.appToken = auth.appToken
      try ConfigStore.save(config)
      paired = true
      availability = .connecting
      statusLine = nil
      requestNotificationPermission()
      startPolling()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  // MARK: Sistema

  func registerAsMagnetHandler() {
    NSWorkspace.shared.setDefaultApplication(
      at: Bundle.main.bundleURL,
      toOpenURLsWithScheme: "magnet"
    ) { [weak self] error in
      Task { @MainActor in
        self?.statusLine =
          error == nil
          ? appString("IliadBar è ora l'app per i link magnet")
          : appString("Registrazione handler fallita: %@", error!.localizedDescription)
      }
    }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    guard Bundle.main.bundleIdentifier != nil else { return }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      launchAtLogin = enabled
    } catch {
      launchAtLogin = SMAppService.mainApp.status == .enabled
      statusLine = appString("Avvio al login: %@", error.localizedDescription)
    }
  }

  func exportDiagnostics() async {
    let panel = NSSavePanel()
    panel.nameFieldStringValue =
      "IliadBar-Diagnostics-\(Self.diagnosticDateFormatter.string(from: Date())).json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    let activeProfile = profiles.first { $0.id == activeProfileID }
    let permissions = await client.permissionSnapshot()
    let report = RedactedDiagnostics(
      app: .init(
        version: IliadBarBuildInfo.version,
        bundleID: Bundle.main.bundleIdentifier ?? "unbundled"
      ),
      macOS: ProcessInfo.processInfo.operatingSystemVersionString,
      box: .init(
        configured: activeProfile != nil,
        deviceType: activeProfile?.deviceType ?? "unknown",
        apiVersion: activeProfile?.apiVersion ?? "unknown",
        transport: URL(string: activeProfile?.baseURL ?? "")?.scheme ?? "unknown",
        paired: paired,
        availability: availability.label
      ),
      permissions: permissions,
      capabilities: advancedCapabilities.map(\.rawValue).sorted(),
      counts: .init(
        downloads: tasks.count,
        storageDisks: storageDisks.count,
        lanHosts: lanHosts.count,
        wifiBSS: wifiBSSs.count,
        dhcpLeases: dhcpLeases.count,
        natRules: portForwardingRules.count
      ),
      liveEvents: liveEventsConnected
    )
    do {
      try report.data().write(to: destination, options: .atomic)
      statusLine = appString("Diagnostica esportata")
    } catch {
      statusLine = appString("Esportazione diagnostica: %@", error.localizedDescription)
    }
  }

  private static let diagnosticDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
  }()

  // MARK: Box profiles and discovery

  func startDiscovery() {
    discovery.start { [weak self] boxes in
      Task { @MainActor in self?.handleDiscoveredBoxes(boxes) }
    } onState: { [weak self] state in
      Task { @MainActor in self?.discoveryState = state }
    }
  }

  private func handleDiscoveredBoxes(_ boxes: [DiscoveredBox]) {
    discoveredBoxes = boxes
    // A legacy installation only knows the historical fixed IP. When one
    // unambiguous box is discovered, upgrade that profile in place so its
    // The stable profile ID preserves the saved credential while URL/API
    // metadata become dynamic.
    guard boxes.count == 1,
      let current = profiles.first(where: { $0.id == activeProfileID }),
      current.id == BoxProfile.legacyID,
      current.uid == nil
    else { return }
    let box = boxes[0]
    let upgraded = BoxProfile(
      id: current.id,
      name: box.name,
      baseURL: box.baseURL.absoluteString,
      uid: box.uid,
      deviceType: box.deviceType,
      apiVersion: box.apiVersion,
      lastSeen: Date()
    )
    do {
      try ConfigStore.saveProfile(upgraded)
      reloadConfiguration()
    } catch {
      statusLine = appString(
        "Discovery riuscita, salvataggio non riuscito: %@", error.localizedDescription)
    }
  }

  func useDiscoveredBox(_ box: DiscoveredBox) {
    do {
      try ConfigStore.saveProfile(box.profile)
      reloadConfiguration()
      statusLine = appString("%@ trovata sulla rete locale", box.name)
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func addManualBox(name: String, baseURL: String) {
    guard IliadboxInputValidator.isSupportedAPIURL(baseURL), let url = URL(string: baseURL) else {
      statusLine = appString("Inserisci un URL API valido")
      return
    }
    let normalized =
      url.absoluteString.hasSuffix("/") ? url.absoluteString : url.absoluteString + "/"
    let profile = BoxProfile(id: UUID().uuidString, name: name, baseURL: normalized)
    do {
      try ConfigStore.saveProfile(profile)
      reloadConfiguration()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func selectProfile(_ id: String) {
    do {
      try ConfigStore.setActiveBox(id)
      reloadConfiguration()
    } catch {
      statusLine = error.localizedDescription
    }
  }

  func removeProfile(_ profile: BoxProfile) {
    do {
      try ConfigStore.removeProfile(profile.id)
      reloadConfiguration()
    } catch {
      statusLine = error.localizedDescription
      reloadConfiguration()
    }
  }

  func updatePreferences(_ transform: (inout AppPreferences) -> Void) {
    var config = ConfigStore.loadAppConfig()
    transform(&config.preferences)
    do {
      try ConfigStore.saveAppConfig(config)
      preferences = config.preferences
      if paired { startPolling() }
    } catch {
      statusLine = error.localizedDescription
    }
  }

  private func reloadConfiguration() {
    let appConfig = ConfigStore.loadAppConfig()
    let runtime = ConfigStore.load()
    profiles = appConfig.boxes
    activeProfileID = appConfig.activeBox?.id
    preferences = appConfig.preferences
    client = IliadboxClient(config: runtime)
    paired = runtime.appToken != nil
    tasks = []
    entries = []
    crumbs = []
    connection = nil
    system = nil
    lanInterfaces = []
    lanHosts = []
    dhcpLeases = []
    dhcpConfig = nil
    wifiConfig = nil
    wifiAccessPoints = []
    wifiBSSs = []
    wifiStations = []
    networkSettingsAllowed = false
    hostInterfaces = [:]
    portForwardingRules = []
    incomingPorts = []
    sambaConfig = nil
    ftpConfig = nil
    upnpIGDConfig = nil
    upnpAVConfig = nil
    connectionConfiguration = nil
    parentalRules = []
    parentalControlAllowed = false
    callLog = []
    contacts = []
    pvrRecords = []
    vpnClientStatus = nil
    vpnServers = []
    selectedParentalPlanning = nil
    advancedCapabilities = []
    availability = appConfig.activeBox == nil ? .unconfigured : .connecting
    pollTask?.cancel()
    eventTask?.cancel()
    liveEventsConnected = false
    if paired { startPolling() }
  }

  // MARK: Helpers

  static func decodeB64Path(_ b64: String) -> String? {
    guard let data = Data(base64Encoded: b64) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func displayName(forMagnet magnet: String) -> String {
    guard let components = URLComponents(string: magnet),
      let dn = components.queryItems?.first(where: { $0.name == "dn" })?.value
    else { return "magnet" }
    return dn
  }

  private func processDownloadTransitions(_ current: [DownloadTask]) {
    let statuses = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0.status ?? "") })
    let events = DownloadTransitionDetector.events(
      previousStatuses: previousTaskStatuses,
      current: current,
      hasBaseline: hasLoadedTasks
    )
    defer {
      previousTaskStatuses = statuses
      hasLoadedTasks = true
    }
    let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
    for event in events {
      guard let task = byID[event.taskID] else { continue }
      switch event.kind {
      case .started:
        notifyDownloadEvent(
          .started,
          title: appString("Download avviato sulla iliadbox"),
          body: task.name ?? "Download \(task.id)")
      case .completed:
        notifyDownloadEvent(
          .completed,
          title: appString("Download completato"),
          body: task.name ?? "Download \(task.id)")
      case .failed:
        notifyDownloadEvent(
          .failed,
          title: appString("Download non riuscito"),
          body: task.name ?? "Download \(task.id)")
      }
    }
  }

  /// Applica la policy per-evento delle notifiche download; il master toggle
  /// resta verificato da notify().
  private func notifyDownloadEvent(_ kind: DownloadTransition.Kind, title: String, body: String) {
    let allowed =
      switch kind {
      case .started: preferences.notifyOnStart
      case .completed: preferences.notifyOnCompletion
      case .failed: preferences.notifyOnFailure
      }
    guard allowed else { return }
    notify(title: title, body: body)
  }

  private func requestNotificationPermission() {
    // UNUserNotificationCenter esplode senza bundle (es. `swift run`): guardia obbligatoria.
    guard Bundle.main.bundleIdentifier != nil, preferences.notificationsEnabled else { return }
    // Niente completion handler sincrona: verrebbe inferita @MainActor ma il
    // servizio la invoca sulla propria coda e il runtime Swift 6 fa trap
    // (dispatch_assert_queue). L'API async gestisce l'hop correttamente.
    Task.detached {
      _ = try? await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound])
    }
  }

  private func notify(title: String, body: String) {
    guard Bundle.main.bundleIdentifier != nil, preferences.notificationsEnabled else { return }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  private func recordFailure(_ error: Error) {
    let message: String
    if let fbxError = error as? FbxError {
      switch fbxError {
      case .api(let code, let apiMessage) where code == "insufficient_rights":
        message = apiMessage ?? appString("Permesso mancante sulla iliadbox")
      case .notPaired:
        message = appString("Associazione richiesta")
        paired = false
      default:
        message = fbxError.localizedDescription
      }
    } else {
      message = error.localizedDescription
    }
    if case .online(let updatedAt) = availability {
      availability = .stale(updatedAt: updatedAt, message: message)
    } else {
      availability = .offline(message: message)
    }
    statusLine = message
    saveWidgetSnapshot()
  }

  private func saveWidgetSnapshot() {
    let relevant = activeTasks.filter { ($0.size ?? 0) > 0 }
    let total = relevant.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
    let received = relevant.reduce(Int64(0)) { $0 + ($1.rxBytes ?? 0) }
    IliadBarWidgetSnapshotStore.save(
      .init(
        online: availability.isOnline,
        downloadRate: connection?.rateDown ?? 0,
        uploadRate: connection?.rateUp ?? 0,
        activeDownloads: activeTasks.count,
        downloadProgress: total > 0 ? Double(received) / Double(total) : nil
      ))
  }
}
