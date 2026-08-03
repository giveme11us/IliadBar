import AppKit
import ServiceManagement
import UserNotifications
import IliadboxKit

@MainActor
final class AppModel: ObservableObject {
    @Published var tasks: [DownloadTask] = []
    @Published var paired: Bool
    @Published var pairingInProgress = false
    /// Feedback transiente (ultimo esito / errore), mostrato sotto l'header.
    @Published var statusLine: String?
    @Published var launchAtLogin: Bool

    private let client: IliadboxClient
    private var pollTask: Task<Void, Never>?

    static let version = "0.1.0"

    init() {
        let config = ConfigStore.load()
        client = IliadboxClient(config: config)
        paired = config.appToken != nil
        launchAtLogin = Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled
        if paired {
            requestNotificationPermission()
            startPolling()
        }
    }

    // MARK: Stato derivato

    var activeTasks: [DownloadTask] {
        tasks.filter { ["downloading", "starting", "checking", "retry", "queued"].contains($0.status ?? "") }
    }

    /// Percentuale aggregata mostrata accanto all'icona in menu bar (stile CodexBar):
    /// visibile solo quando c'è almeno un download attivo.
    var menuBarPercent: String? {
        let downloading = activeTasks.filter { ($0.size ?? 0) > 0 }
        guard !downloading.isEmpty else { return nil }
        let total = downloading.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        let received = downloading.reduce(Int64(0)) { $0 + ($1.rxBytes ?? 0) }
        guard total > 0 else { return nil }
        return "\(Int(Double(received) / Double(total) * 100))%"
    }

    // MARK: Polling

    /// Cadenza adattiva: serrata coi download attivi, rilassata a riposo.
    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let seconds: UInt64 = (self?.activeTasks.isEmpty == false) ? 3 : 20
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    func refresh() async {
        guard paired else { return }
        do {
            let list = try await client.listDownloads()
            // Attivi in testa, poi i più recenti.
            tasks = list.sorted { lhs, rhs in
                let la = isActive(lhs), ra = isActive(rhs)
                if la != ra { return la }
                return lhs.id > rhs.id
            }
        } catch {
            statusLine = "iliadbox non raggiungibile"
        }
    }

    private func isActive(_ task: DownloadTask) -> Bool {
        ["downloading", "starting", "checking", "retry", "queued"].contains(task.status ?? "")
    }

    // MARK: Azioni download

    func add(magnet: String) async {
        guard paired else {
            statusLine = "Prima associa MagnetBox alla iliadbox"
            return
        }
        do {
            let id = try await client.addDownload(url: magnet)
            let name = (try? await client.download(id: id))?.name ?? displayName(forMagnet: magnet)
            statusLine = nil
            notify(title: "Download avviato sulla iliadbox", body: name)
            await refresh()
        } catch {
            statusLine = error.localizedDescription
            notify(title: "Errore download", body: error.localizedDescription)
        }
    }

    func addFromPasteboard() async {
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            text.hasPrefix("magnet:")
        else {
            statusLine = "Negli appunti non c'è un link magnet"
            return
        }
        await add(magnet: text)
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
    func remove(_ task: DownloadTask) async {
        do {
            try await client.deleteDownload(id: task.id, eraseFiles: false)
            await refresh()
        } catch {
            statusLine = error.localizedDescription
        }
    }

    // MARK: Pairing (dal pannello)

    func pair() async {
        pairingInProgress = true
        statusLine = "Conferma la richiesta sulla iliadbox…"
        defer { pairingInProgress = false }
        do {
            let deviceName = Host.current().localizedName ?? "Mac"
            let auth = try await client.requestAuthorization(deviceName: deviceName)
            try await client.waitForApproval(trackId: auth.trackId)
            var config = ConfigStore.load()
            config.appToken = auth.appToken
            try ConfigStore.save(config)
            paired = true
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
                self?.statusLine = error == nil
                    ? "MagnetBox è ora l'app per i link magnet"
                    : "Registrazione handler fallita: \(error!.localizedDescription)"
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
            statusLine = "Avvio al login: \(error.localizedDescription)"
        }
    }

    // MARK: Helpers

    private func displayName(forMagnet magnet: String) -> String {
        guard let components = URLComponents(string: magnet),
              let dn = components.queryItems?.first(where: { $0.name == "dn" })?.value
        else { return "magnet" }
        return dn
    }

    private func requestNotificationPermission() {
        // UNUserNotificationCenter esplode senza bundle (es. `swift run`): guardia obbligatoria.
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
