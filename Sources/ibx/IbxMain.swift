import Foundation
import IliadboxKit

@main
struct IbxMain {
  static func main() async {
    let rawArgs = Array(CommandLine.arguments.dropFirst())
    let json = rawArgs.contains("--json")
    let args = rawArgs.filter { $0 != "--json" }
    do {
      switch args.first {
      case "discover":
        try await discover(save: args.contains("--save"), json: json)
      case "profiles":
        try profiles(json: json)
      case "keychain-authorize":
        try keychainAuthorize()
      case "use":
        guard args.count >= 2 else { fail("uso: ibx use <profile-id>") }
        try useProfile(id: args[1])
      case "pair":
        try await pair()
      case "status":
        try await status(json: json)
      case "add":
        guard args.count >= 2 else { fail("uso: ibx add <magnet|url>") }
        try await add(url: args[1])
      case "list":
        try await list(json: json)
      case "rm":
        guard args.count >= 2, let id = Int(args[1]) else { fail("uso: ibx rm <id> [--erase]") }
        try await remove(id: id, erase: args.contains("--erase"))
      case "box":
        try await box(json: json)
      case "storage":
        try await storage(json: json)
      case "ls":
        try await ls(path: args.count >= 2 ? args[1] : nil, json: json)
      case "network":
        try await network(json: json)
      case "services":
        try await services(json: json)
      default:
        usage()
      }
    } catch {
      fail(diagnosticDescription(error))
    }
  }

  static func usage() {
    print(
      """
      ibx — CLI per la iliadbox (IliadBar)

      USO: ibx <comando>
        pair              Associa questo Mac alla iliadbox (conferma fisica sulla box)
        discover [--save] Cerca iliadbox/Freebox OS sulla rete locale
        profiles          Elenca le box salvate
        keychain-authorize Verifica la credenziale salvata (alias compatibile)
        use <profile-id>  Seleziona la box attiva
        status            Stato sessione e permessi
        add <magnet|url>  Aggiunge un download sulla box
        list              Elenca i task di download
        rm <id> [--erase] Rimuove un task (--erase cancella anche i file)
        box               Info e stats della box (connessione, sistema)
        storage           Elenca dischi e partizioni
        ls [path]         Elenca la cartella download (o un path della box)
        network           Ispeziona LAN, DHCP e Wi-Fi
        services          Ispeziona NAT e servizi di rete

      Aggiungi --json per un output stabile adatto all'automazione.

      Config: ~/Library/Application Support/IliadBar/config.json
      """)
  }

  static func diagnosticDescription(_ error: Error) -> String {
    var parts: [String] = []
    var current: NSError? = error as NSError
    while let diagnostic = current {
      parts.append("\(diagnostic.localizedDescription) [\(diagnostic.domain):\(diagnostic.code)]")
      current = diagnostic.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return parts.joined(separator: " ← ")
  }

  static func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("errore: \(message)\n".utf8))
    exit(1)
  }

  // MARK: Comandi

  static func discover(save: Bool, json: Bool) async throws {
    let accumulator = DiscoveryAccumulator()
    let discovery = IliadboxDiscovery()
    discovery.start { boxes in
      Task { await accumulator.replace(with: boxes) }
    } onState: { state in
      Task { await accumulator.setState(state) }
    }
    try await Task.sleep(nanoseconds: 3_000_000_000)
    discovery.cancel()

    let boxes = await accumulator.boxes
    guard !boxes.isEmpty else {
      let state = await accumulator.state
      if case .failed(let message) = state { throw CliError.message(message) }
      if json {
        try emitJSON([])
      } else {
        print("Nessuna iliadbox trovata sulla rete locale.")
      }
      return
    }
    if json {
      try emitJSON(
        boxes.map { box in
          [
            "id": box.id,
            "name": box.name,
            "api_version": box.apiVersion,
            "base_url": box.baseURL.absoluteString,
            "https": box.supportsHTTPS,
          ] as [String: Any]
        })
    } else {
      for box in boxes {
        print("[\(box.id)] \(box.name)")
        print("  API \(box.apiVersion) · \(box.baseURL.absoluteString)")
      }
    }
    guard save else { return }

    let config = ConfigStore.loadAppConfig()
    if boxes.count == 1, let active = config.activeBox, active.id == BoxProfile.legacyID {
      let box = boxes[0]
      let upgraded = BoxProfile(
        id: active.id,
        name: box.name,
        baseURL: box.baseURL.absoluteString,
        uid: box.uid,
        deviceType: box.deviceType,
        apiVersion: box.apiVersion,
        lastSeen: Date()
      )
      try ConfigStore.saveProfile(upgraded)
      if !json { print("✓ Profilo legacy aggiornato con discovery e HTTPS") }
    } else {
      for (index, box) in boxes.enumerated() {
        try ConfigStore.saveProfile(box.profile, makeActive: config.boxes.isEmpty && index == 0)
      }
      if !json { print("✓ \(boxes.count) box salvate") }
    }
  }

  static func profiles(json: Bool) throws {
    let config = ConfigStore.loadAppConfig()
    guard !config.boxes.isEmpty else {
      if json {
        try emitJSON([])
      } else {
        print("Nessuna box salvata. Esegui `ibx discover`.")
      }
      return
    }
    if json {
      try emitJSON(
        config.boxes.map { profile in
          [
            "id": profile.id,
            "name": profile.name,
            "base_url": profile.baseURL,
            "active": profile.id == config.activeBox?.id,
            "paired": profile.appToken != nil,
          ] as [String: Any]
        })
      return
    }
    for profile in config.boxes {
      let marker = profile.id == config.activeBox?.id ? "*" : " "
      let state = profile.appToken == nil ? "non associata" : "associata"
      print("\(marker) [\(profile.id)] \(profile.name) · \(state)")
      print("    \(profile.baseURL)")
    }
  }

  static func useProfile(id: String) throws {
    let config = ConfigStore.loadAppConfig()
    guard let profile = config.boxes.first(where: { $0.id == id }) else {
      throw CliError.message("Profilo non trovato: \(id)")
    }
    try ConfigStore.setActiveBox(id)
    print("✓ Box attiva: \(profile.name)")
  }

  static func keychainAuthorize() throws {
    guard let profile = ConfigStore.loadAppConfig().activeBox else {
      throw CliError.message("Nessuna box configurata")
    }
    guard profile.appToken != nil else {
      throw CliError.message("Nessun token salvato per \(profile.name)")
    }
    print("✓ Credenziale disponibile nel file di configurazione privato")
  }

  static func pair() async throws {
    var config = ConfigStore.load(allowKeychainInteraction: false)
    if config.appToken != nil {
      print("Già associato (token in \(ConfigStore.fileURL.path)).")
      print("Per ri-associare, cancella il file di config e rilancia `ibx pair`.")
      return
    }
    let client = IliadboxClient(config: config)
    let deviceName = Host.current().localizedName ?? "Mac"
    let auth = try await client.requestAuthorization(deviceName: deviceName)
    print("Richiesta inviata alla iliadbox (track \(auth.trackId)).")
    print(">>> Vai alla box e CONFERMA la richiesta di associazione. Attendo...")

    try await client.waitForApproval(trackId: auth.trackId) { status in
      if status == "pending" { print("  ...in attesa di conferma sulla box") }
    }

    config.appToken = auth.appToken
    try ConfigStore.save(config)
    print("✓ Associato! Token salvato in \(ConfigStore.fileURL.path)")

    let session = try await client.openSession()
    printPermissions(session.permissions ?? [:])
  }

  static func status(json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let session = try await client.openSession()
    if json {
      try emitJSON(["connected": true, "permissions": session.permissions ?? [:]])
      return
    }
    print("✓ Sessione aperta con la iliadbox.")
    printPermissions(session.permissions ?? [:])
  }

  static func add(url: String) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let id = try await client.addDownload(url: url)
    print("✓ Download aggiunto, task id \(id)")
    // Snapshot subito dopo l'aggiunta, per feedback immediato.
    if let task = try? await client.download(id: id) {
      print("  \(task.name ?? "-") [\(task.status ?? "-")]")
    }
  }

  static func list(json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let tasks = try await client.listDownloads()
    if json {
      try emitJSON(
        tasks.map { task in
          [
            "id": task.id, "name": task.name ?? "", "status": task.status ?? "",
            "progress": task.progress,
          ] as [String: Any]
        })
      return
    }
    guard !tasks.isEmpty else {
      print("Nessun task di download sulla box.")
      return
    }
    for task in tasks {
      let pct = String(format: "%3.0f%%", task.progress * 100)
      print("[\(task.id)] \(pct) \(task.status ?? "-")  \(task.name ?? "-")")
    }
  }

  static func remove(id: Int, erase: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    try await client.deleteDownload(id: id, eraseFiles: erase)
    print("✓ Task \(id) rimosso\(erase ? " (file inclusi)" : "")")
  }

  static func box(json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let connection = try await client.connectionStatus()
    let system = try await client.systemInfo()
    if json {
      // Sotto-espressioni tipizzate: il literal unico manda in timeout il
      // type-checker delle toolchain meno recenti (runner CI).
      let connectionPayload: [String: Any] = [
        "state": connection.state ?? "", "media": connection.media ?? "",
        "ipv4": connection.ipv4 ?? "",
        "rate_down": connection.rateDown ?? 0, "rate_up": connection.rateUp ?? 0,
        "bandwidth_down": connection.bandwidthDown ?? 0,
        "bandwidth_up": connection.bandwidthUp ?? 0,
        "ipv4_port_range": connection.ipv4PortRange ?? [],
      ]
      let systemPayload: [String: Any] = [
        "model": system.modelName ?? "", "firmware": system.firmwareVersion ?? "",
        "uptime": system.uptimeVal ?? 0, "max_temperature": system.maxTemperature ?? 0,
      ]
      try emitJSON(["connection": connectionPayload, "system": systemPayload])
      return
    }

    let state = connection.isUp ? "connessa" : (connection.state ?? "-")
    print(
      "Connessione: \(state) [\(connection.media?.uppercased() ?? "-")]  IPv4 \(connection.ipv4 ?? "-")"
    )
    let down = (connection.rateDown ?? 0) / 1024
    let up = (connection.rateUp ?? 0) / 1024
    print("Velocità:    ↓ \(down) KiB/s  ↑ \(up) KiB/s")
    if let bandwidthDown = connection.bandwidthDown, let bandwidthUp = connection.bandwidthUp {
      print(
        "Banda max:   ↓ \(bandwidthDown / 1_000_000) Mbit/s  ↑ \(bandwidthUp / 1_000_000) Mbit/s")
    }
    print("Modello:     \(system.modelName ?? "-")")
    print("Firmware:    \(system.firmwareVersion ?? "-")")
    if let uptime = system.uptimeVal {
      print("Uptime:      \(uptime / 86400)g \((uptime % 86400) / 3600)h")
    }
    if let temperature = system.maxTemperature {
      print("Temperatura: \(temperature) °C")
    }
  }

  static func ls(path: String?, json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let pathB64: String
    if let path {
      pathB64 = Data(path.utf8).base64EncodedString()
    } else {
      pathB64 = try await client.downloadsDirectory()
      if !json,
        let decoded = Data(base64Encoded: pathB64).flatMap({ String(data: $0, encoding: .utf8) })
      {
        print("(cartella download della box: \(decoded))")
      }
    }
    let entries = try await client.listFolder(pathB64: pathB64)
    if json {
      try emitJSON(
        entries.map { entry in
          [
            "name": entry.name, "path": entry.path, "directory": entry.isDirectory,
            "size": entry.size ?? 0,
          ] as [String: Any]
        })
      return
    }
    guard !entries.isEmpty else {
      print("(cartella vuota)")
      return
    }
    for entry in entries {
      let marker = entry.isDirectory ? "d" : "-"
      let size = entry.isDirectory ? "" : " \((entry.size ?? 0) / 1024) KiB"
      print("\(marker) \(entry.name)\(size)")
    }
  }

  static func storage(json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let disks = try await client.storageDisks()
    if json {
      try emitJSON(
        disks.map { disk in
          [
            "id": disk.id, "name": disk.name ?? "", "model": disk.model ?? "",
            "state": disk.state ?? "",
            "partitions": (disk.partitions ?? []).map { partition in
              [
                "id": partition.id, "label": partition.label ?? "",
                "free_bytes": partition.freeBytes ?? 0,
              ]
            },
          ] as [String: Any]
        })
      return
    }
    guard !disks.isEmpty else {
      print("Nessun disco rilevato.")
      return
    }
    for disk in disks {
      print("[\(disk.id)] \(disk.name ?? disk.model ?? "Disco") · \(disk.state ?? "-")")
      for partition in disk.partitions ?? [] {
        let free =
          partition.freeBytes.map { "\($0 / 1_000_000_000) GB liberi" } ?? "spazio sconosciuto"
        print("  [\(partition.id)] \(partition.label ?? "Partizione") · \(free)")
      }
    }
  }

  static func network(json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    let interfaces = try await client.lanInterfaces()
    var hosts: [LanHost] = []
    for interface in interfaces {
      hosts += (try? await client.lanHosts(interface: interface.name)) ?? []
    }
    async let dhcp = try? client.dhcpConfig()
    async let leases = try? client.dhcpStaticLeases()
    async let wifi = try? client.wifiGlobalConfig()
    async let bss = try? client.wifiBSSList()
    let result = await (dhcp, leases, wifi, bss)
    let payload: [String: Any] = [
      "interfaces": interfaces.map { ["name": $0.name, "host_count": $0.hostCount ?? 0] },
      "hosts": hosts.map {
        [
          "id": $0.id, "name": $0.primaryName, "ip": $0.ipv4Address ?? "",
          "mac": $0.macAddress ?? "", "reachable": $0.reachable ?? false,
        ] as [String: Any]
      },
      "dhcp": [
        "enabled": result.0?.enabled ?? false, "range_start": result.0?.rangeStart ?? "",
        "range_end": result.0?.rangeEnd ?? "",
      ],
      "static_leases": (result.1 ?? []).map {
        ["id": $0.id, "ip": $0.ip, "mac": $0.mac, "hostname": $0.hostname ?? ""]
      },
      "wifi": ["enabled": result.2?.enabled ?? false],
      "ssids": (result.3 ?? []).map {
        [
          "id": $0.id, "ssid": $0.config?.ssid ?? "", "enabled": $0.config?.enabled ?? false,
          "stations": $0.status?.stationCount ?? 0,
        ] as [String: Any]
      },
    ]
    if json {
      try emitJSON(payload)
      return
    }
    print("LAN: \(hosts.count) dispositivi su \(interfaces.count) interfacce")
    print(
      "DHCP: \(result.0?.enabled == true ? "attivo" : "disattivo") · \(result.1?.count ?? 0) prenotazioni"
    )
    print(
      "Wi-Fi: \(result.2?.enabled == true ? "attivo" : "disattivo") · \(result.3?.count ?? 0) SSID")
  }

  static func services(json: Bool) async throws {
    let client = IliadboxClient(config: ConfigStore.load(allowKeychainInteraction: false))
    async let nat = try? client.portForwardingRules()
    async let incoming = try? client.incomingPorts()
    async let samba = try? client.sambaConfig()
    async let ftp = try? client.ftpConfig()
    async let igd = try? client.upnpIGDConfig()
    let result = await (nat, incoming, samba, ftp, igd)
    let payload: [String: Any] = [
      "nat": (result.0 ?? []).map {
        [
          "id": $0.id, "enabled": $0.enabled, "protocol": $0.protocolName,
          "public_port": $0.wanPortStart.intValue, "lan_ip": $0.lanIP, "lan_port": $0.lanPort,
        ] as [String: Any]
      },
      "incoming_ports": (result.1 ?? []).map {
        ["id": $0.id, "enabled": $0.enabled, "active": $0.active ?? false, "port": $0.port]
          as [String: Any]
      },
      "samba": ["available": result.2 != nil, "enabled": result.2?.fileShareEnabled ?? false],
      "ftp": ["available": result.3 != nil, "enabled": result.3?.enabled ?? false],
      "upnp_igd": ["available": result.4 != nil, "enabled": result.4?.enabled ?? false],
    ]
    if json {
      try emitJSON(payload)
      return
    }
    print("NAT: \(result.0?.count ?? 0) regole · \(result.1?.count ?? 0) porte gestite")
    print("SMB: \(result.2?.fileShareEnabled == true ? "attivo" : "disattivo")")
    print("FTP: \(result.3?.enabled == true ? "attivo" : "disattivo")")
    print("UPnP IGD: \(result.4?.enabled == true ? "attivo" : "disattivo")")
  }

  static func emitJSON(_ value: Any) throws {
    let data = try AutomationJSON.data(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }

  static func printPermissions(_ permissions: [String: Bool]) {
    guard !permissions.isEmpty else { return }
    print("Permessi:")
    for (key, value) in permissions.sorted(by: { $0.key < $1.key }) {
      print("  \(value ? "✓" : "✗") \(key)")
    }
    if permissions["downloader"] != true {
      print("⚠️  Permesso 'downloader' mancante: abilitalo da iliadbox OS →")
      print("   Impostazioni → Gestione accessi → Applicazioni → IliadBar")
    }
  }
}

private actor DiscoveryAccumulator {
  var boxes: [DiscoveredBox] = []
  var state: DiscoveryState = .idle

  func replace(with boxes: [DiscoveredBox]) { self.boxes = boxes }
  func setState(_ state: DiscoveryState) { self.state = state }
}

private enum CliError: Error, LocalizedError {
  case message(String)
  var errorDescription: String? {
    if case .message(let message) = self { return message }
    return nil
  }
}
