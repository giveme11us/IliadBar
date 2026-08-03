import Foundation
import IliadboxKit

@main
struct IbxMain {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            switch args.first {
            case "pair":
                try await pair()
            case "status":
                try await status()
            case "add":
                guard args.count >= 2 else { fail("uso: ibx add <magnet|url>") }
                try await add(url: args[1])
            case "list":
                try await list()
            case "rm":
                guard args.count >= 2, let id = Int(args[1]) else { fail("uso: ibx rm <id> [--erase]") }
                try await remove(id: id, erase: args.contains("--erase"))
            case "box":
                try await box()
            case "ls":
                try await ls(path: args.count >= 2 ? args[1] : nil)
            default:
                usage()
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    static func usage() {
        print("""
        ibx — CLI per la iliadbox (IliadBar)

        USO: ibx <comando>
          pair              Associa questo Mac alla iliadbox (conferma fisica sulla box)
          status            Stato sessione e permessi
          add <magnet|url>  Aggiunge un download sulla box
          list              Elenca i task di download
          rm <id> [--erase] Rimuove un task (--erase cancella anche i file)
          box               Info e stats della box (connessione, sistema)
          ls [path]         Elenca la cartella download (o un path della box)

        Config: ~/Library/Application Support/IliadBar/config.json
        """)
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("errore: \(message)\n".utf8))
        exit(1)
    }

    // MARK: Comandi

    static func pair() async throws {
        var config = ConfigStore.load()
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

    static func status() async throws {
        let client = IliadboxClient(config: ConfigStore.load())
        let session = try await client.openSession()
        print("✓ Sessione aperta con la iliadbox.")
        printPermissions(session.permissions ?? [:])
    }

    static func add(url: String) async throws {
        let client = IliadboxClient(config: ConfigStore.load())
        let id = try await client.addDownload(url: url)
        print("✓ Download aggiunto, task id \(id)")
        // Snapshot subito dopo l'aggiunta, per feedback immediato.
        if let task = try? await client.download(id: id) {
            print("  \(task.name ?? "-") [\(task.status ?? "-")]")
        }
    }

    static func list() async throws {
        let client = IliadboxClient(config: ConfigStore.load())
        let tasks = try await client.listDownloads()
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
        let client = IliadboxClient(config: ConfigStore.load())
        try await client.deleteDownload(id: id, eraseFiles: erase)
        print("✓ Task \(id) rimosso\(erase ? " (file inclusi)" : "")")
    }

    static func box() async throws {
        let client = IliadboxClient(config: ConfigStore.load())
        let connection = try await client.connectionStatus()
        let system = try await client.systemInfo()

        let state = connection.isUp ? "connessa" : (connection.state ?? "-")
        print("Connessione: \(state) [\(connection.media?.uppercased() ?? "-")]  IPv4 \(connection.ipv4 ?? "-")")
        let down = (connection.rateDown ?? 0) / 1024
        let up = (connection.rateUp ?? 0) / 1024
        print("Velocità:    ↓ \(down) KiB/s  ↑ \(up) KiB/s")
        if let bandwidthDown = connection.bandwidthDown, let bandwidthUp = connection.bandwidthUp {
            print("Banda max:   ↓ \(bandwidthDown / 1_000_000) Mbit/s  ↑ \(bandwidthUp / 1_000_000) Mbit/s")
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

    static func ls(path: String?) async throws {
        let client = IliadboxClient(config: ConfigStore.load())
        let pathB64: String
        if let path {
            pathB64 = Data(path.utf8).base64EncodedString()
        } else {
            pathB64 = try await client.downloadsDirectory()
            if let decoded = Data(base64Encoded: pathB64).flatMap({ String(data: $0, encoding: .utf8) }) {
                print("(cartella download della box: \(decoded))")
            }
        }
        let entries = try await client.listFolder(pathB64: pathB64)
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
