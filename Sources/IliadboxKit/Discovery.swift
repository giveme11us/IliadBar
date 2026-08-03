import Foundation
import Network

public struct DiscoveredBox: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let baseURL: URL
  public let uid: String?
  public let deviceType: String?
  public let apiVersion: String
  public let supportsHTTPS: Bool

  public init(
    id: String,
    name: String,
    baseURL: URL,
    uid: String?,
    deviceType: String?,
    apiVersion: String,
    supportsHTTPS: Bool
  ) {
    self.id = id
    self.name = name
    self.baseURL = baseURL
    self.uid = uid
    self.deviceType = deviceType
    self.apiVersion = apiVersion
    self.supportsHTTPS = supportsHTTPS
  }

  public var profile: BoxProfile {
    BoxProfile(
      id: id,
      name: name,
      baseURL: baseURL.absoluteString,
      uid: uid,
      deviceType: deviceType,
      apiVersion: apiVersion,
      lastSeen: Date()
    )
  }

  /// Converts the TXT record advertised by `_fbx-api._tcp` into a stable
  /// profile. This stays pure so firmware variants can be covered by fixtures.
  public static func parse(serviceName: String, txt: [String: String]) -> DiscoveredBox? {
    guard let apiDomain = nonEmpty(txt["api_domain"]) else { return nil }
    let apiVersion = nonEmpty(txt["api_version"]) ?? "1.0"
    let majorVersion = apiVersion.split(separator: ".").first.map(String.init) ?? apiVersion
    let rawBasePath = nonEmpty(txt["api_base_url"]) ?? "/api/"
    let basePath = normalizedBasePath(rawBasePath)
    let supportsHTTPS = bool(txt["https_available"])
    let scheme = supportsHTTPS ? "https" : "http"

    var components = URLComponents()
    components.scheme = scheme
    components.host = apiDomain
    if supportsHTTPS, let rawPort = txt["https_port"], let port = Int(rawPort), port > 0 {
      components.port = port
    }
    components.path = "\(basePath)v\(majorVersion)/"
    guard let url = components.url else { return nil }

    let uid = nonEmpty(txt["uid"])
    return DiscoveredBox(
      id: uid ?? apiDomain,
      name: nonEmpty(txt["device_name"]) ?? serviceName,
      baseURL: url,
      uid: uid,
      deviceType: nonEmpty(txt["device_type"]),
      apiVersion: apiVersion,
      supportsHTTPS: supportsHTTPS
    )
  }

  private static func normalizedBasePath(_ value: String) -> String {
    var path = value
    if !path.hasPrefix("/") { path = "/" + path }
    if !path.hasSuffix("/") { path += "/" }
    return path
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func bool(_ value: String?) -> Bool {
    guard let value else { return false }
    return ["1", "true", "yes"].contains(value.lowercased())
  }
}

public enum DiscoveryState: Equatable, Sendable {
  case idle
  case searching
  case ready
  case waiting(String)
  case failed(String)
}

/// Bonjour browser for Freebox OS gateways. It uses Network.framework so the
/// browser owns its queue and callbacks are safe to consume from any surface.
public final class IliadboxDiscovery: @unchecked Sendable {
  public typealias ResultsHandler = @Sendable ([DiscoveredBox]) -> Void
  public typealias StateHandler = @Sendable (DiscoveryState) -> Void

  private let queue = DispatchQueue(label: "it.ivansposato.iliadbar.discovery")
  private var browser: NWBrowser?

  public init() {}

  public func start(onResults: @escaping ResultsHandler, onState: @escaping StateHandler) {
    cancel()
    let parameters = NWParameters.tcp
    parameters.includePeerToPeer = true
    let browser = NWBrowser(
      for: .bonjourWithTXTRecord(type: "_fbx-api._tcp", domain: nil),
      using: parameters
    )
    self.browser = browser
    onState(.searching)

    browser.stateUpdateHandler = { state in
      switch state {
      case .ready:
        onState(.ready)
      case .waiting(let error):
        onState(.waiting(error.localizedDescription))
      case .failed(let error):
        onState(.failed(error.localizedDescription))
      case .cancelled:
        onState(.idle)
      case .setup:
        onState(.searching)
      @unknown default:
        onState(.failed("Stato Bonjour sconosciuto"))
      }
    }
    browser.browseResultsChangedHandler = { results, _ in
      let boxes = results.compactMap(Self.parse).sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      onResults(boxes)
    }
    browser.start(queue: queue)
  }

  public func cancel() {
    browser?.cancel()
    browser = nil
  }

  deinit {
    browser?.cancel()
  }

  private static func parse(_ result: NWBrowser.Result) -> DiscoveredBox? {
    guard case .service(let name, _, _, _) = result.endpoint else { return nil }
    guard case .bonjour(let record) = result.metadata else { return nil }
    return DiscoveredBox.parse(serviceName: name, txt: record.dictionary)
  }
}
