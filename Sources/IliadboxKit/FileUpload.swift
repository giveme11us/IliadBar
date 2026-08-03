import Foundation

public enum UploadConflictMode: String, Sendable {
  case missing
  case overwrite
  case resume
}

private struct UploadAction: Encodable {
  let action: String
  let requestID: Int
  let size: Int64?
  let dirname: String?
  let filename: String?
  let force: String?

  enum CodingKeys: String, CodingKey {
    case action, size, dirname, filename, force
    case requestID = "request_id"
  }
}

private struct UploadProgress: Decodable {
  let totalLength: Int64?
  let complete: Bool?
  let cancelled: Bool?

  enum CodingKeys: String, CodingKey {
    case totalLength = "total_len"
    case complete, cancelled
  }
}

private struct UploadResponse: Decodable {
  let action: String?
  let requestID: Int?
  let success: Bool
  let errorCode: String?
  let message: String?
  let result: UploadProgress?

  enum CodingKeys: String, CodingKey {
    case action, success, result
    case requestID = "request_id"
    case errorCode = "error_code"
    case message = "msg"
  }
}

extension IliadboxClient {
  /// Uploads a file through the v4+ WebSocket API. Chunks stay below the
  /// protocol's 1 MB frame limit and progress is reported from box acks.
  public func uploadFile(
    data: Data,
    filename: String,
    destinationB64: String,
    conflictMode: UploadConflictMode = .missing,
    onProgress: @escaping @Sendable (Int64, Int64) -> Void = { _, _ in }
  ) async throws {
    var offset = 0
    try await uploadStream(
      size: Int64(data.count),
      filename: filename,
      destinationB64: destinationB64,
      conflictMode: conflictMode,
      onProgress: onProgress
    ) {
      guard offset < data.count else { return nil }
      let end = min(offset + 512 * 1024, data.count)
      defer { offset = end }
      return data.subdata(in: offset..<end)
    }
  }

  /// Streams a local file without loading it entirely in memory. This is the
  /// path used by the app for large transfers.
  public func uploadFile(
    at fileURL: URL,
    filename: String,
    destinationB64: String,
    conflictMode: UploadConflictMode = .missing,
    onProgress: @escaping @Sendable (Int64, Int64) -> Void = { _, _ in }
  ) async throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard let number = attributes[.size] as? NSNumber else { throw FbxError.invalidResponse }
    let size = number.int64Value
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }
    try await uploadStream(
      size: size,
      filename: filename,
      destinationB64: destinationB64,
      conflictMode: conflictMode,
      onProgress: onProgress
    ) {
      try handle.read(upToCount: 512 * 1024)
    }
  }

  private func uploadStream(
    size: Int64,
    filename: String,
    destinationB64: String,
    conflictMode: UploadConflictMode,
    onProgress: @escaping @Sendable (Int64, Int64) -> Void,
    nextChunk: () throws -> Data?
  ) async throws {
    if sessionToken == nil { try await openSession() }
    guard let sessionToken else { throw FbxError.notPaired }
    guard let webSocketURL = websocketUploadURL() else { throw FbxError.invalidResponse }

    var request = URLRequest(url: webSocketURL)
    request.setValue(sessionToken, forHTTPHeaderField: "X-Fbx-App-Auth")
    let socket = urlSession.webSocketTask(with: request)
    let requestID = Int.random(in: 1...Int.max / 2)
    socket.resume()

    do {
      let start = UploadAction(
        action: "upload_start",
        requestID: requestID,
        size: size,
        dirname: destinationB64,
        filename: filename,
        force: conflictMode.rawValue
      )
      try await Self.send(start, through: socket)
      let startResponse = try await Self.receive(from: socket)
      guard startResponse.success else {
        throw FbxError.api(code: startResponse.errorCode, message: startResponse.message)
      }

      let acknowledgements = Task {
        while !Task.isCancelled {
          let response = try await Self.receive(from: socket)
          guard response.success else {
            throw FbxError.api(code: response.errorCode, message: response.message)
          }
          if let uploaded = response.result?.totalLength {
            onProgress(uploaded, size)
          }
          if response.result?.complete == true { return }
        }
      }

      while let chunk = try nextChunk(), !chunk.isEmpty {
        try Task.checkCancellation()
        try await socket.send(.data(chunk))
      }
      let finalize = UploadAction(
        action: "upload_finalize",
        requestID: requestID,
        size: nil,
        dirname: nil,
        filename: nil,
        force: nil
      )
      try await Self.send(finalize, through: socket)
      try await acknowledgements.value
      socket.cancel(with: .normalClosure, reason: nil)
    } catch {
      if error is CancellationError || Task.isCancelled {
        let cancel = UploadAction(
          action: "upload_cancel",
          requestID: requestID,
          size: nil,
          dirname: nil,
          filename: nil,
          force: nil
        )
        try? await Self.send(cancel, through: socket)
      }
      socket.cancel(with: .goingAway, reason: nil)
      throw error
    }
  }

  private func websocketUploadURL() -> URL? {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
      return nil
    }
    components.scheme = components.scheme == "https" ? "wss" : "ws"
    if !components.path.hasSuffix("/") { components.path += "/" }
    components.path += "ws/upload"
    return components.url
  }

  private static func send(_ action: UploadAction, through socket: URLSessionWebSocketTask)
    async throws
  {
    let data = try JSONEncoder().encode(action)
    guard let text = String(data: data, encoding: .utf8) else { throw FbxError.invalidResponse }
    try await socket.send(.string(text))
  }

  private static func receive(from socket: URLSessionWebSocketTask) async throws -> UploadResponse {
    let message = try await socket.receive()
    let data: Data
    switch message {
    case .string(let text): data = Data(text.utf8)
    case .data(let value): data = value
    @unknown default: throw FbxError.invalidResponse
    }
    return try JSONDecoder().decode(UploadResponse.self, from: data)
  }
}
