import Foundation

/// Config condivisa tra CLI (`ibx`) e app (IliadBar):
/// ~/Library/Application Support/IliadBar/config.json (0600 — contiene l'app_token).
public struct IbxConfig: Codable, Sendable {
    public var baseURL: String
    public var appToken: String?

    public init(baseURL: String = "http://192.168.1.254/api/v15/", appToken: String? = nil) {
        self.baseURL = baseURL
        self.appToken = appToken
    }
}

public enum ConfigStore {
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IliadBar", isDirectory: true)
    }

    public static var fileURL: URL {
        directory.appendingPathComponent("config.json")
    }

    public static func load() -> IbxConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(IbxConfig.self, from: data)
        else { return IbxConfig() }
        return config
    }

    public static func save(_ config: IbxConfig) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
        // L'app_token dà pieno controllo della box: solo l'utente deve poterlo leggere.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
