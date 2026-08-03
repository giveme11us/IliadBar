import Foundation

/// Task di download sulla box. Campi quasi tutti opzionali:
/// lo schema varia tra versioni firmware e tipi di task.
public struct DownloadTask: Decodable, Identifiable, Sendable {
    public let id: Int
    public let name: String?
    public let status: String?
    public let size: Int64?
    public let rxBytes: Int64?
    public let rxRate: Int64?
    public let eta: Int64?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status, size, eta, error
        case rxBytes = "rx_bytes"
        case rxRate = "rx_rate"
    }

    public var progress: Double {
        guard let size, size > 0, let rxBytes else { return 0 }
        return Double(rxBytes) / Double(size)
    }
}

struct AddDownloadResult: Decodable {
    let id: Int
}

public extension IliadboxClient {
    /// Aggiunge un download da magnet link o URL (http/ftp/.torrent remoto).
    /// `directory`: path assoluto sulla box (es. "/Disque dur/Téléchargements"),
    /// nil = cartella di download predefinita configurata sulla box.
    @discardableResult
    func addDownload(url: String, directory: String? = nil) async throws -> Int {
        var form = ["download_url": url]
        if let directory {
            form["download_dir"] = Data(directory.utf8).base64EncodedString()
        }
        let result: AddDownloadResult = try await authedCall("downloads/add/", method: "POST", formBody: form)
        return result.id
    }

    func listDownloads() async throws -> [DownloadTask] {
        // result assente quando non c'è nessun task: normalizziamo a [].
        do {
            return try await authedCall("downloads/")
        } catch FbxError.invalidResponse {
            return []
        }
    }

    func download(id: Int) async throws -> DownloadTask {
        try await authedCall("downloads/\(id)")
    }

    /// eraseFiles: cancella anche i file scaricati, non solo il task.
    func deleteDownload(id: Int, eraseFiles: Bool = false) async throws {
        let path = eraseFiles ? "downloads/\(id)/erase" : "downloads/\(id)"
        let _: FbxEmpty = try await authedCall(path, method: "DELETE")
    }
}
