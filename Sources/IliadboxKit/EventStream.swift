import Foundation

public struct BoxEventMessage: Decodable, Sendable {
  public let action: String
  public let success: Bool?
  public let source: String?
  public let event: String?
}

extension IliadboxClient {
  /// Stream eventi generico Freebox OS (`/ws/event`). La registrazione è
  /// esplicita: firmware che non espongono il canale falliscono e il chiamante
  /// può mantenere il polling come fallback.
  public func eventMessages(events: [String]) async throws -> AsyncThrowingStream<
    BoxEventMessage, Error
  > {
    if sessionToken == nil { try await openSession() }
    guard let sessionToken else { throw FbxError.notPaired }

    var components = URLComponents(
      url: URL(string: "ws/event", relativeTo: baseURL)!, resolvingAgainstBaseURL: true)
    components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
    guard let url = components?.url else { throw FbxError.invalidResponse }
    var request = URLRequest(url: url)
    request.setValue(sessionToken, forHTTPHeaderField: "X-Fbx-App-Auth")
    let socket = urlSession.webSocketTask(with: request)
    socket.resume()

    struct Registration: Encodable {
      let action = "register"
      let events: [String]
    }
    let registration = try JSONEncoder().encode(Registration(events: events))
    try await socket.send(.data(registration))

    return AsyncThrowingStream { continuation in
      let receiver = Task {
        do {
          while !Task.isCancelled {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case .data(let value): data = value
            case .string(let value): data = Data(value.utf8)
            @unknown default: continue
            }
            continuation.yield(try JSONDecoder().decode(BoxEventMessage.self, from: data))
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { @Sendable _ in
        receiver.cancel()
        socket.cancel(with: .goingAway, reason: nil)
      }
    }
  }
}
