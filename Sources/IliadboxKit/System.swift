import Foundation

// MARK: - system/ — informazioni sulla box

public struct SystemSensor: Decodable, Sendable {
  public let id: String?
  public let name: String?
  public let value: Int?
}

public struct SystemModelInfo: Decodable, Sendable {
  public let prettyName: String?

  enum CodingKeys: String, CodingKey {
    case prettyName = "pretty_name"
  }
}

public struct SystemInfo: Decodable, Sendable {
  public let firmwareVersion: String?
  public let uptimeVal: Int64?
  public let uptime: String?
  public let boardName: String?
  public let sensors: [SystemSensor]?
  public let modelInfo: SystemModelInfo?

  enum CodingKeys: String, CodingKey {
    case firmwareVersion = "firmware_version"
    case uptimeVal = "uptime_val"
    case uptime
    case boardName = "board_name"
    case sensors
    case modelInfo = "model_info"
  }

  /// Temperatura più alta tra i sensori termici (°C).
  public var maxTemperature: Int? {
    sensors?
      .filter { ($0.id ?? "").contains("temp") }
      .compactMap(\.value)
      .max()
  }

  public var modelName: String? {
    modelInfo?.prettyName ?? boardName
  }
}

// MARK: - connection/ — stato e velocità della connessione

public struct ConnectionStatus: Decodable, Sendable {
  public let state: String?
  public let media: String?  // es. "ftth"
  public let type: String?
  public let ipv4: String?
  /// Velocità istantanee in byte/s.
  public let rateDown: Int64?
  public let rateUp: Int64?
  /// Banda massima in bit/s.
  public let bandwidthDown: Int64?
  public let bandwidthUp: Int64?
  /// Range di porte IPv4 pubbliche assegnato dal provider (estremi inclusi).
  public let ipv4PortRange: [Int]?

  enum CodingKeys: String, CodingKey {
    case state, media, type, ipv4
    case rateDown = "rate_down"
    case rateUp = "rate_up"
    case bandwidthDown = "bandwidth_down"
    case bandwidthUp = "bandwidth_up"
    case ipv4PortRange = "ipv4_port_range"
  }

  public var isUp: Bool { state == "up" }

  public var assignedPortRange: ClosedRange<Int>? {
    guard let ipv4PortRange, ipv4PortRange.count >= 2 else { return nil }
    return ipv4PortRange[0]...ipv4PortRange[1]
  }

  /// Percentuale di banda usata (rate è in byte/s, bandwidth in bit/s).
  public static func usagePercent(rate: Int64?, bandwidth: Int64?) -> Double {
    guard let rate, let bandwidth, bandwidth > 0 else { return 0 }
    return min(100, Double(rate * 8) / Double(bandwidth) * 100)
  }
}

extension IliadboxClient {
  public func systemInfo() async throws -> SystemInfo {
    try await authedCall("system/")
  }

  public func connectionStatus() async throws -> ConnectionStatus {
    try await authedCall("connection/")
  }
}
