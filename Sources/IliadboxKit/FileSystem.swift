import Foundation

// MARK: - fs/ — filesystem della box
// L'API identifica i path col loro base64: lo trattiamo come token opaco
// (si naviga partendo da download_dir e dai path restituiti da fs/ls).

public struct FsEntry: Decodable, Identifiable, Sendable {
    /// Path base64-encoded, come lo vuole l'API.
    public let path: String
    public let name: String
    public let type: String?       // "dir" | "file"
    public let size: Int64?
    public let modification: Int64?
    public let hidden: Bool?

    // "." e ".." hanno lo stesso path della cartella/genitore: il path da solo
    // non è univoco come id, il nome sì (entro la stessa cartella).
    public var id: String { path + "|" + name }
    public var isDirectory: Bool { type == "dir" }
}

/// Su firmware recenti fs/ls incapsula in {"entries": [...]}; su altri è un array nudo.
struct FsListing: Decodable {
    let entries: [FsEntry]?
}

struct DownloadsConfigResult: Decodable {
    let downloadDir: String?       // base64

    enum CodingKeys: String, CodingKey {
        case downloadDir = "download_dir"
    }
}

public extension IliadboxClient {
    /// Cartella di destinazione dei download configurata sulla box (path base64).
    func downloadsDirectory() async throws -> String {
        let config: DownloadsConfigResult = try await authedCall("downloads/config/")
        guard let dir = config.downloadDir, !dir.isEmpty else { throw FbxError.invalidResponse }
        return dir
    }

    /// Elenca una cartella. `pathB64` è il path base64 (da downloadsDirectory o da un FsEntry).
    /// `.`, `..` e i file nascosti vengono filtrati (removeHidden lato API non basta).
    func listFolder(pathB64: String) async throws -> [FsEntry] {
        let path = "fs/ls/\(Self.escapePathSegment(pathB64))?removeHidden=1"
        let raw: [FsEntry]
        do {
            let listing: FsListing = try await authedCall(path)
            raw = listing.entries ?? []
        } catch FbxError.invalidResponse {
            // Firmware che rispondono con l'array nudo (o result assente = vuota).
            let fallback: [FsEntry]? = try? await authedCall(path)
            raw = fallback ?? []
        }
        return raw.filter { $0.hidden != true && $0.name != "." && $0.name != ".." }
    }

    /// Scarica un file dalla box in `directory` sul Mac (endpoint dl/, risposta raw,
    /// fuori dalla busta JSON). Ritorna l'URL di destinazione effettivo.
    func downloadFile(pathB64: String, toDirectory directory: URL, suggestedName: String) async throws -> URL {
        if sessionToken == nil { try await openSession() }

        func attempt() async throws -> (URL, HTTPURLResponse) {
            var request = URLRequest(url: URL(string: "dl/\(Self.escapePathSegment(pathB64))", relativeTo: baseURL)!)
            request.timeoutInterval = 3600 // file grandi
            if let token = sessionToken {
                request.setValue(token, forHTTPHeaderField: "X-Fbx-App-Auth")
            }
            let (tmp, response) = try await urlSession.download(for: request)
            guard let http = response as? HTTPURLResponse else { throw FbxError.invalidResponse }
            return (tmp, http)
        }

        var (tmp, http) = try await attempt()
        if http.statusCode == 403 {
            try await openSession()
            (tmp, http) = try await attempt()
        }
        guard (200...299).contains(http.statusCode) else { throw FbxError.http(status: http.statusCode) }

        let destination = Self.uniqueDestination(in: directory, name: suggestedName)
        try FileManager.default.moveItem(at: tmp, to: destination)
        return destination
    }

    /// Il base64 può contenere "/" e "+": vanno percent-encodati per stare
    /// in un segmento di URL senza farsi interpretare dal router della box.
    static func escapePathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    static func uniqueDestination(in directory: URL, name: String) -> URL {
        let base = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: name).pathExtension
        var candidate = directory.appendingPathComponent(name)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(numbered)
            counter += 1
        }
        return candidate
    }
}
