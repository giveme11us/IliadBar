import Foundation

public struct RedactedDiagnostics: Codable, Sendable {
  public struct App: Codable, Sendable {
    public let version: String
    public let bundleID: String

    enum CodingKeys: String, CodingKey {
      case version
      case bundleID = "bundle_id"
    }

    public init(version: String, bundleID: String) {
      self.version = version
      self.bundleID = bundleID
    }
  }

  public struct Box: Codable, Sendable {
    public let configured: Bool
    public let deviceType: String
    public let apiVersion: String
    public let transport: String
    public let paired: Bool
    public let availability: String

    enum CodingKeys: String, CodingKey {
      case configured, transport, paired, availability
      case deviceType = "device_type"
      case apiVersion = "api_version"
    }

    public init(
      configured: Bool,
      deviceType: String,
      apiVersion: String,
      transport: String,
      paired: Bool,
      availability: String
    ) {
      self.configured = configured
      self.deviceType = deviceType
      self.apiVersion = apiVersion
      self.transport = transport
      self.paired = paired
      self.availability = availability
    }
  }

  public struct Counts: Codable, Sendable {
    public let downloads: Int
    public let storageDisks: Int
    public let lanHosts: Int
    public let wifiBSS: Int
    public let dhcpLeases: Int
    public let natRules: Int

    enum CodingKeys: String, CodingKey {
      case downloads
      case storageDisks = "storage_disks"
      case lanHosts = "lan_hosts"
      case wifiBSS = "wifi_bss"
      case dhcpLeases = "dhcp_leases"
      case natRules = "nat_rules"
    }

    public init(
      downloads: Int,
      storageDisks: Int,
      lanHosts: Int,
      wifiBSS: Int,
      dhcpLeases: Int,
      natRules: Int
    ) {
      self.downloads = downloads
      self.storageDisks = storageDisks
      self.lanHosts = lanHosts
      self.wifiBSS = wifiBSS
      self.dhcpLeases = dhcpLeases
      self.natRules = natRules
    }
  }

  public let generatedAt: Date
  public let app: App
  public let macOS: String
  public let box: Box
  public let permissions: [String: Bool]
  public let capabilities: [String]
  public let counts: Counts
  public let liveEvents: Bool
  public let redaction: String

  enum CodingKeys: String, CodingKey {
    case app, box, permissions, capabilities, counts, redaction
    case generatedAt = "generated_at"
    case macOS = "macos"
    case liveEvents = "live_events"
  }

  public init(
    generatedAt: Date = Date(),
    app: App,
    macOS: String,
    box: Box,
    permissions: [String: Bool],
    capabilities: [String],
    counts: Counts,
    liveEvents: Bool
  ) {
    self.generatedAt = generatedAt
    self.app = app
    self.macOS = macOS
    self.box = box
    self.permissions = permissions
    self.capabilities = capabilities
    self.counts = counts
    self.liveEvents = liveEvents
    redaction =
      "Tokens, session keys, status messages, hostnames, IP addresses, MAC addresses, device names, Wi-Fi keys and box URLs are intentionally omitted."
  }

  public func data() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(self)
  }
}
