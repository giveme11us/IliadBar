import Foundation

public enum FileConflictMode: String, CaseIterable, Codable, Sendable {
  case overwrite
  case both
  case recent
  case skip
}

// MARK: - fs/ — filesystem della box
// L'API identifica i path col loro base64: lo trattiamo come token opaco
// (si naviga partendo da download_dir e dai path restituiti da fs/ls).

public struct FsEntry: Decodable, Identifiable, Sendable {
  /// Path base64-encoded, come lo vuole l'API.
  public let path: String
  public let name: String
  public let type: String?  // "dir" | "file"
  public let size: Int64?
  public let modification: Int64?
  public let hidden: Bool?

  // "." e ".." hanno lo stesso path della cartella/genitore: il path da solo
  // non è univoco come id, il nome sì (entro la stessa cartella).
  public var id: String { path + "|" + name }
  public var isDirectory: Bool { type == "dir" }
}

public struct FsTask: Decodable, Identifiable, Sendable {
  public let id: Int
  public let type: String?
  public let state: String?
  public let error: String?
  public let progress: Int?
  public let rate: Int64?
  public let eta: Int64?
  public let totalBytes: Int64?
  public let completedBytes: Int64?
  public let fileCount: Int?
  public let completedFileCount: Int?

  enum CodingKeys: String, CodingKey {
    case id, type, state, error, progress, rate, eta
    case totalBytes = "total_bytes"
    case completedBytes = "total_bytes_done"
    case fileCount = "nfiles"
    case completedFileCount = "nfiles_done"
  }
}

public struct ShareLink: Decodable, Identifiable, Sendable {
  public let token: String
  public let path: String
  public let name: String?
  public let expiration: Int64?
  public let fullURL: String?
  public var id: String { token }

  enum CodingKeys: String, CodingKey {
    case token, path, name
    case expiration = "expire"
    case fullURL = "fullurl"
  }
}

public struct StoragePartition: Decodable, Identifiable, Sendable {
  public let id: Int
  public let label: String?
  public let fileSystem: String?
  public let path: String?
  public let totalBytes: Int64?
  public let usedBytes: Int64?
  public let freeBytes: Int64?
  public let state: String?
  public let fsckResult: String?
  public let operationPercent: Int?

  enum CodingKeys: String, CodingKey {
    case id, label, path, state
    case fileSystem = "fstype"
    case totalBytes = "total_bytes"
    case usedBytes = "used_bytes"
    case freeBytes = "free_bytes"
    case fsckResult = "fsck_result"
    case operationPercent = "operation_pct"
  }
}

public struct StorageDisk: Decodable, Identifiable, Sendable {
  public let id: Int
  public let type: String?
  public let connector: String?
  public let name: String?
  public let model: String?
  public let serial: String?
  public let firmware: String?
  public let state: String?
  public let temperature: Int?
  public let totalBytes: Int64?
  public let partitions: [StoragePartition]?

  enum CodingKeys: String, CodingKey {
    case id, type, connector, name, model, serial, firmware, state, partitions
    case temperature = "temp"
    case totalBytes = "total_bytes"
  }
}

/// Su firmware recenti fs/ls incapsula in {"entries": [...]}; su altri è un array nudo.
struct FsListing: Decodable {
  let entries: [FsEntry]?
}

struct DownloadsConfigResult: Decodable {
  let downloadDir: String?  // base64

  enum CodingKeys: String, CodingKey {
    case downloadDir = "download_dir"
  }
}

extension IliadboxClient {
  public static var rootPathB64: String { Data("/".utf8).base64EncodedString() }

  /// Scompone un path base64 nelle sue tappe ("/SSD/Download" → SSD, Download),
  /// ognuna col proprio path base64: serve a ricostruire una navigazione
  /// completa quando si atterra direttamente in una sottocartella.
  public static func pathSteps(forPathB64 pathB64: String) -> [(name: String, pathB64: String)] {
    guard let data = Data(base64Encoded: pathB64),
      let path = String(data: data, encoding: .utf8)
    else { return [] }
    var current = ""
    var steps: [(name: String, pathB64: String)] = []
    for component in path.split(separator: "/") {
      current += "/\(component)"
      steps.append((String(component), Data(current.utf8).base64EncodedString()))
    }
    return steps
  }

  /// Cartella di destinazione dei download configurata sulla box (path base64).
  public func downloadsDirectory() async throws -> String {
    let config: DownloadsConfigResult = try await authedCall("downloads/config/")
    guard let dir = config.downloadDir, !dir.isEmpty else { throw FbxError.invalidResponse }
    return dir
  }

  /// Elenca una cartella. `pathB64` è il path base64 (da downloadsDirectory o da un FsEntry).
  /// `.`, `..` e i file nascosti vengono filtrati (removeHidden lato API non basta).
  public func listFolder(pathB64: String) async throws -> [FsEntry] {
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

  public func createDirectory(parentB64: String, name: String) async throws {
    struct Body: Encodable {
      let parent: String
      let dirname: String
    }
    let _: FbxEmpty = try await authedCall(
      "fs/mkdir/",
      method: "POST",
      jsonBody: Body(parent: parentB64, dirname: name)
    )
  }

  @discardableResult
  public func rename(pathB64: String, to newName: String) async throws -> String {
    struct Body: Encodable {
      let src: String
      let dst: String
    }
    return try await authedCall(
      "fs/rename/",
      method: "POST",
      jsonBody: Body(src: pathB64, dst: newName)
    )
  }

  @discardableResult
  public func move(
    pathsB64: [String],
    to destinationB64: String,
    mode: FileConflictMode = .both
  )
    async throws -> FsTask
  {
    struct Body: Encodable {
      let files: [String]
      let dst: String
      let mode: FileConflictMode
    }
    return try await authedCall(
      "fs/mv/",
      method: "POST",
      jsonBody: Body(files: pathsB64, dst: destinationB64, mode: mode)
    )
  }

  @discardableResult
  public func copy(
    pathsB64: [String],
    to destinationB64: String,
    mode: FileConflictMode = .both
  )
    async throws -> FsTask
  {
    struct Body: Encodable {
      let files: [String]
      let dst: String
      let mode: FileConflictMode
    }
    return try await authedCall(
      "fs/cp/",
      method: "POST",
      jsonBody: Body(files: pathsB64, dst: destinationB64, mode: mode)
    )
  }

  @discardableResult
  public func remove(pathsB64: [String]) async throws -> FsTask {
    struct Body: Encodable { let files: [String] }
    return try await authedCall("fs/rm/", method: "POST", jsonBody: Body(files: pathsB64))
  }

  public func filesystemTasks() async throws -> [FsTask] { try await authedCall("fs/tasks/") }
  public func filesystemTask(id: Int) async throws -> FsTask {
    try await authedCall("fs/tasks/\(id)")
  }
  public func cancelFilesystemTask(id: Int) async throws {
    let _: FbxEmpty = try await authedCall("fs/tasks/\(id)", method: "DELETE")
  }

  public func shareLinks() async throws -> [ShareLink] { try await authedCall("share_link/") }
  public func createShareLink(pathB64: String, expiration: Int64 = 0) async throws -> ShareLink {
    struct Body: Encodable {
      let path: String
      let expire: Int64
      let fullurl: String
    }
    return try await authedCall(
      "share_link/",
      method: "POST",
      jsonBody: Body(path: pathB64, expire: expiration, fullurl: "")
    )
  }
  public func deleteShareLink(token: String) async throws {
    let escaped = Self.escapePathSegment(token)
    let _: FbxEmpty = try await authedCall("share_link/\(escaped)", method: "DELETE")
  }

  public func storageDisks() async throws -> [StorageDisk] { try await authedCall("storage/disk") }

  /// Scarica un file dalla box in `directory` sul Mac (endpoint dl/, risposta raw,
  /// fuori dalla busta JSON). Ritorna l'URL di destinazione effettivo.
  public func downloadFile(pathB64: String, toDirectory directory: URL, suggestedName: String)
    async throws -> URL
  {
    if sessionToken == nil { try await openSession() }

    func attempt() async throws -> (URL, HTTPURLResponse) {
      var request = URLRequest(
        url: URL(string: "dl/\(Self.escapePathSegment(pathB64))", relativeTo: baseURL)!)
      request.timeoutInterval = 3600  // file grandi
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
    guard (200...299).contains(http.statusCode) else {
      throw FbxError.http(status: http.statusCode)
    }

    let destination = Self.uniqueDestination(in: directory, name: suggestedName)
    try FileManager.default.moveItem(at: tmp, to: destination)
    return destination
  }

  /// Il base64 può contenere "/" e "+": vanno percent-encodati per stare
  /// in un segmento di URL senza farsi interpretare dal router della box.
  public static func escapePathSegment(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
  }

  public static func uniqueDestination(in directory: URL, name: String) -> URL {
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
