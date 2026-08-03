import AppKit
import UserNotifications
import IliadboxKit

@MainActor
final class AppModel: ObservableObject {
    @Published var statusLine: String

    private let client: IliadboxClient
    private let paired: Bool

    init() {
        let config = ConfigStore.load()
        client = IliadboxClient(config: config)
        paired = config.appToken != nil
        statusLine = paired ? "Pronto — iliadbox associata" : "Non associato: esegui `ibx pair` nel terminale"
        if paired { requestNotificationPermission() }
    }

    func add(magnet: String) async {
        guard paired else {
            statusLine = "Non associato: esegui `ibx pair` nel terminale"
            notify(title: "MagnetBox non associata", body: "Esegui `ibx pair` nel terminale, poi riprova.")
            return
        }
        do {
            let id = try await client.addDownload(url: magnet)
            let name = (try? await client.download(id: id))?.name ?? displayName(forMagnet: magnet)
            statusLine = "In download: \(name)"
            notify(title: "Download avviato sulla iliadbox", body: name)
        } catch {
            statusLine = "Errore: \(error.localizedDescription)"
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

    /// Chiede a macOS di rendere MagnetBox l'app predefinita per magnet:
    /// (il sistema mostra una conferma all'utente).
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

    // MARK: Helpers

    /// Estrae il display name (dn=) dal magnet per un feedback leggibile
    /// senza dover attendere i metadati dalla box.
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
