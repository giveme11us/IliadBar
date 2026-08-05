import Foundation

public struct DownloadTask: Decodable, Identifiable, Sendable {
  public let id: Int
  public let name: String?
  public let status: String?
  public let type: String?
  public let size: Int64?
  public let rxBytes: Int64?
  public let txBytes: Int64?
  public let rxRate: Int64?
  public let txRate: Int64?
  public let eta: Int64?
  public let error: String?
  public let queuePosition: Int?
  public let ioPriority: String?
  public let createdTimestamp: Int64?
  public let downloadDirectory: String?
  public let infoHash: String?
  public let pieceLength: Int64?
  public let rxPercent: Int?
  public let txPercent: Int?
  public let stopRatio: Int?

  enum CodingKeys: String, CodingKey {
    case id, name, status, type, size, eta, error
    case rxBytes = "rx_bytes"
    case txBytes = "tx_bytes"
    case rxRate = "rx_rate"
    case txRate = "tx_rate"
    case queuePosition = "queue_pos"
    case ioPriority = "io_priority"
    case createdTimestamp = "created_ts"
    case downloadDirectory = "download_dir"
    case infoHash = "info_hash"
    case pieceLength = "piece_length"
    case rxPercent = "rx_pct"
    case txPercent = "tx_pct"
    case stopRatio = "stop_ratio"
  }

  public var progress: Double {
    if let rxPercent { return min(1, max(0, Double(rxPercent) / 10_000)) }
    guard let size, size > 0, let rxBytes else { return 0 }
    return min(1, max(0, Double(rxBytes) / Double(size)))
  }

  public var isActive: Bool {
    ["downloading", "starting", "checking", "retry", "queued", "repairing", "extracting"].contains(
      status ?? "")
  }

  public var isFinished: Bool { ["done", "seeding"].contains(status ?? "") }
  public var hasFailed: Bool { status == "error" || (error != nil && error != "none") }

  /// Tempo residuo in secondi, `nil` quando non è stimabile.
  ///
  /// La box manda `eta: 0` sia quando mancano zero secondi sia quando non sa
  /// rispondere, e mostrare quello zero come "0s" significa promettere una
  /// fine imminente. Se il dato manca lo ricaviamo da byte residui e
  /// velocità, che abbiamo già.
  public var estimatedSecondsRemaining: Int64? {
    if let eta, eta > 0 { return eta }
    guard let size, let rxBytes, let rxRate, rxRate > 0, size > rxBytes else { return nil }
    return (size - rxBytes) / rxRate
  }

  /// In download ma senza traffico: succede senza peer o con la coda ferma.
  /// È diverso da "lento", e va detto invece di lasciare un tempo vuoto.
  public var isStalled: Bool {
    status == "downloading" && (rxRate ?? 0) <= 0 && !isFinished
  }
}

public struct DownloadTransition: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case started
    case completed
    case failed
  }

  public let taskID: Int
  public let kind: Kind

  public init(taskID: Int, kind: Kind) {
    self.taskID = taskID
    self.kind = kind
  }
}

public enum DownloadTransitionDetector {
  public static func events(
    previousStatuses: [Int: String],
    current: [DownloadTask],
    hasBaseline: Bool
  ) -> [DownloadTransition] {
    guard hasBaseline else { return [] }
    return current.compactMap { task in
      let status = task.status ?? ""
      let previous = previousStatuses[task.id]
      guard previous != status else { return nil }
      if task.hasFailed { return DownloadTransition(taskID: task.id, kind: .failed) }
      if task.isFinished { return DownloadTransition(taskID: task.id, kind: .completed) }
      if task.isActive, previous.map({ !activeStatuses.contains($0) }) ?? true {
        return DownloadTransition(taskID: task.id, kind: .started)
      }
      return nil
    }
  }

  private static let activeStatuses: Set<String> = [
    "downloading", "starting", "checking", "retry", "queued", "repairing", "extracting",
  ]
}

public struct DownloadStats: Decodable, Sendable {
  public let rxRate: Int64?
  public let txRate: Int64?
  public let taskCount: Int?
  public let activeCount: Int?
  public let downloadingCount: Int?
  public let seedingCount: Int?
  public let doneCount: Int?
  public let errorCount: Int?
  public let throttlingMode: String?

  enum CodingKeys: String, CodingKey {
    case rxRate = "rx_rate"
    case txRate = "tx_rate"
    case taskCount = "nb_tasks"
    case activeCount = "nb_tasks_active"
    case downloadingCount = "nb_tasks_downloading"
    case seedingCount = "nb_tasks_seeding"
    case doneCount = "nb_tasks_done"
    case errorCount = "nb_tasks_error"
    case throttlingMode = "throttling_mode"
  }
}

public struct DownloadFile: Decodable, Identifiable, Sendable {
  public let id: String
  public let taskID: FlexibleInt?
  public let filepath: String?
  public let name: String
  public let mimeType: String?
  public let size: Int64?
  public let received: Int64?
  public let status: String?
  public let error: String?
  public let priority: String?
  public let previewURL: String?

  enum CodingKeys: String, CodingKey {
    case id, filepath, name, size, status, error, priority
    case taskID = "task_id"
    case mimeType = "mimetype"
    case received = "rx"
    case previewURL = "preview_url"
  }

  public var progress: Double {
    guard let size, size > 0, let received else { return status == "done" ? 1 : 0 }
    return min(1, Double(received) / Double(size))
  }
}

public struct DownloadTracker: Decodable, Identifiable, Sendable {
  public let announce: String
  public let isBackup: Bool?
  public let status: String?
  public let interval: Int?
  public let minimumInterval: Int?
  public let reannounceIn: Int?
  public let seeders: Int?
  public let leechers: Int?
  public let isEnabled: Bool?
  public var id: String { announce }

  enum CodingKeys: String, CodingKey {
    case announce, status, interval
    case isBackup = "is_backup"
    case minimumInterval = "min_interval"
    case reannounceIn = "reannounce_in"
    case seeders = "nseeders"
    case leechers = "nleechers"
    case isEnabled = "is_enabled"
  }
}

public struct DownloadPeer: Decodable, Identifiable, Sendable {
  public let host: String
  public let port: Int?
  public let state: String?
  public let origin: String?
  public let transportProtocol: String?
  public let client: String?
  public let countryCode: String?
  public let transmitted: Int64?
  public let received: Int64?
  public let txRate: Int64?
  public let rxRate: Int64?
  public let progress: Int?
  public var id: String { "\(host):\(port ?? 0)" }

  enum CodingKeys: String, CodingKey {
    case host, port, state, origin, client, progress
    case transportProtocol = "protocol"
    case countryCode = "country_code"
    case transmitted = "tx"
    case received = "rx"
    case txRate = "tx_rate"
    case rxRate = "rx_rate"
  }
}

/// Some firmware versions encode task IDs as strings in nested resources.
public enum FlexibleInt: Decodable, Sendable, Equatable {
  case value(Int)

  public var intValue: Int {
    switch self {
    case .value(let value): value
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(Int.self) {
      self = .value(value)
      return
    }
    if let raw = try? container.decode(String.self), let value = Int(raw) {
      self = .value(value)
      return
    }
    throw DecodingError.dataCorruptedError(
      in: container, debugDescription: "Expected integer or integer string")
  }
}

struct AddDownloadResult: Decodable { let id: Int }

extension IliadboxClient {
  @discardableResult
  public func addDownload(url: String, directory: String? = nil) async throws -> Int {
    var form = ["download_url": url]
    if let directory { form["download_dir"] = Data(directory.utf8).base64EncodedString() }
    let result: AddDownloadResult = try await authedCall(
      "downloads/add/", method: "POST", formBody: form)
    return result.id
  }

  @discardableResult
  public func addDownloadFile(data: Data, filename: String, directoryB64: String? = nil)
    async throws -> Int
  {
    let boundary = "IliadBar-\(UUID().uuidString)"
    let body = Self.multipartBody(
      boundary: boundary,
      fields: directoryB64.map { ["download_dir": $0] } ?? [:],
      fileField: "download_file",
      filename: filename,
      contentType: filename.lowercased().hasSuffix(".nzb")
        ? "application/x-nzb" : "application/x-bittorrent",
      fileData: data
    )
    let result: AddDownloadResult = try await authedCall(
      "downloads/add/",
      method: "POST",
      rawBody: body,
      contentType: "multipart/form-data; boundary=\(boundary)"
    )
    return result.id
  }

  public func listDownloads() async throws -> [DownloadTask] {
    do { return try await authedCall("downloads/") } catch FbxError.invalidResponse { return [] }
  }

  public func download(id: Int) async throws -> DownloadTask {
    try await authedCall("downloads/\(id)")
  }
  public func downloadStats() async throws -> DownloadStats {
    try await authedCall("downloads/stats")
  }
  public func downloadFiles(id: Int) async throws -> [DownloadFile] {
    try await authedCall("downloads/\(id)/files")
  }
  public func downloadTrackers(id: Int) async throws -> [DownloadTracker] {
    try await authedCall("downloads/\(id)/trackers")
  }
  public func downloadPeers(id: Int) async throws -> [DownloadPeer] {
    try await authedCall("downloads/\(id)/peers")
  }
  public func downloadPieces(id: Int) async throws -> String {
    try await authedCall("downloads/\(id)/pieces")
  }

  public func deleteDownload(id: Int, eraseFiles: Bool = false) async throws {
    let path = eraseFiles ? "downloads/\(id)/erase" : "downloads/\(id)"
    let _: FbxEmpty = try await authedCall(path, method: "DELETE")
  }

  @discardableResult
  public func pauseDownload(id: Int) async throws -> DownloadTask {
    try await updateDownload(id: id, values: ["status": "stopped"])
  }
  @discardableResult
  public func resumeDownload(id: Int) async throws -> DownloadTask {
    try await updateDownload(id: id, values: ["status": "downloading"])
  }
  @discardableResult
  public func retryDownload(id: Int) async throws -> DownloadTask {
    try await updateDownload(id: id, values: ["status": "retry"])
  }
  @discardableResult
  public func setDownloadPriority(id: Int, priority: String) async throws -> DownloadTask {
    try await updateDownload(id: id, values: ["io_priority": priority])
  }

  public func setDownloadFilePriority(taskID: Int, fileID: String, priority: String) async throws {
    struct Body: Encodable { let priority: String }
    let escaped = Self.escapePathSegment(fileID)
    let _: FbxEmpty = try await authedCall(
      "downloads/\(taskID)/files/\(escaped)",
      method: "PUT",
      jsonBody: Body(priority: priority)
    )
  }

  private func updateDownload(id: Int, values: [String: String]) async throws -> DownloadTask {
    try await authedCall("downloads/\(id)", method: "PUT", jsonBody: values)
  }

  public static func multipartBody(
    boundary: String,
    fields: [String: String],
    fileField: String,
    filename: String,
    contentType: String,
    fileData: Data
  ) -> Data {
    var body = Data()
    func append(_ value: String) { body.append(Data(value.utf8)) }
    for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
      append("--\(boundary)\r\n")
      append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
      append("\(value)\r\n")
    }
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n")
    append("Content-Type: \(contentType)\r\n\r\n")
    body.append(fileData)
    append("\r\n--\(boundary)--\r\n")
    return body
  }
}
