import Foundation

public struct LanInterface: Decodable, Identifiable, Sendable {
  public let name: String
  public let hostCount: Int?
  public var id: String { name }
  enum CodingKeys: String, CodingKey {
    case name
    case hostCount = "host_count"
  }
}

public struct LanHostName: Decodable, Sendable {
  public let name: String
  public let source: String?
}

public struct LanHostL2Identity: Decodable, Sendable {
  public let id: String
  public let type: String?
}

public struct LanHostConnectivity: Decodable, Sendable {
  public let address: String
  public let family: String?
  public let active: Bool?
  public let reachable: Bool?
  public let lastActivity: Int64?
  public let lastReachable: Int64?

  enum CodingKeys: String, CodingKey {
    case address = "addr"
    case family = "af"
    case active, reachable
    case lastActivity = "last_activity"
    case lastReachable = "last_time_reachable"
  }
}

public struct LanAccessPoint: Decodable, Sendable {
  public let connectivityType: String?
  public let receiveRate: Int64?
  public let transmitRate: Int64?
  public let wifiInformation: WifiConnectionInformation?
  public let ethernetInformation: EthernetConnectionInformation?

  enum CodingKeys: String, CodingKey {
    case connectivityType = "connectivity_type"
    case receiveRate = "rx_rate"
    case transmitRate = "tx_rate"
    case wifiInformation = "wifi_information"
    case ethernetInformation = "ethernet_information"
  }
}

public struct WifiConnectionInformation: Decodable, Sendable {
  public let band: String?
  public let ssid: String?
  public let signal: Int?
}

public struct EthernetConnectionInformation: Decodable, Sendable {
  public let speed: Int?
  public let duplex: String?
  public let link: String?
}

public struct LanHost: Decodable, Identifiable, Sendable {
  public let id: String
  public let primaryName: String
  public let hostType: String?
  public let primaryNameManual: Bool?
  public let l2Identity: OneOrMany<LanHostL2Identity>?
  public let vendorName: String?
  public let persistent: Bool?
  public let reachable: Bool?
  public let active: Bool?
  public let lastActivity: Int64?
  public let lastReachable: Int64?
  public let names: [LanHostName]?
  public let connectivities: [LanHostConnectivity]?
  public let accessPoint: LanAccessPoint?

  enum CodingKeys: String, CodingKey {
    case id, persistent, reachable, active, names
    case primaryName = "primary_name"
    case hostType = "host_type"
    case primaryNameManual = "primary_name_manual"
    case l2Identity = "l2ident"
    case vendorName = "vendor_name"
    case lastActivity = "last_activity"
    case lastReachable = "last_time_reachable"
    case connectivities = "l3connectivities"
    case accessPoint = "access_point"
  }

  public var ipv4Address: String? {
    connectivities?.first { $0.family == "ipv4" && $0.active == true }?.address
      ?? connectivities?.first { $0.family == "ipv4" }?.address
  }

  public var macAddress: String? { l2Identity?.values.first?.id }
}

public struct OneOrMany<Value: Decodable & Sendable>: Decodable, Sendable {
  public let values: [Value]
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let many = try? container.decode([Value].self) {
      values = many
    } else {
      values = [try container.decode(Value.self)]
    }
  }
}

public struct DhcpStaticLease: Decodable, Identifiable, Sendable {
  public let id: String
  public let mac: String
  public let comment: String?
  public let hostname: String?
  public let ip: String
  public let host: LanHost?
}

public struct DhcpConfig: Decodable, Sendable {
  public let enabled: Bool
  public let gateway: String?
  public let networkMask: String?
  public let rangeStart: String?
  public let rangeEnd: String?
  public let dns: [String]?
  public let alwaysBroadcast: Bool?
  enum CodingKeys: String, CodingKey {
    case enabled, gateway, dns
    case networkMask = "netmask"
    case rangeStart = "ip_range_start"
    case rangeEnd = "ip_range_end"
    case alwaysBroadcast = "always_broadcast"
  }
}

public struct WifiGlobalConfig: Decodable, Sendable {
  public let enabled: Bool
  public let macFilterState: String?
  enum CodingKeys: String, CodingKey {
    case enabled
    case macFilterState = "mac_filter_state"
  }
}

public struct WifiAPStatus: Decodable, Sendable {
  public let state: String?
  public let channelWidth: FlexibleInt?
  public let primaryChannel: Int?
  public let secondaryChannel: Int?
  enum CodingKeys: String, CodingKey {
    case state
    case channelWidth = "channel_width"
    case primaryChannel = "primary_channel"
    case secondaryChannel = "secondary_channel"
  }
}

public struct WifiAPConfig: Decodable, Sendable {
  public let band: String?
  public let channelWidth: FlexibleInt?
  public let primaryChannel: Int?
  public let secondaryChannel: Int?
  public let dfsEnabled: Bool?
  enum CodingKeys: String, CodingKey {
    case band
    case channelWidth = "channel_width"
    case primaryChannel = "primary_channel"
    case secondaryChannel = "secondary_channel"
    case dfsEnabled = "dfs_enabled"
  }
}

public struct WifiAccessPoint: Decodable, Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let status: WifiAPStatus?
  public let config: WifiAPConfig?
}

public struct WifiBSSStatus: Decodable, Sendable {
  public let state: String?
  public let stationCount: Int?
  public let authorizedStationCount: Int?
  public let isMain: Bool?
  enum CodingKeys: String, CodingKey {
    case state
    case stationCount = "sta_count"
    case authorizedStationCount = "authorized_sta_count"
    case isMain = "is_main_bss"
  }
}

public struct WifiBSSConfig: Decodable, Sendable {
  public let enabled: Bool?
  public let ssid: String?
  public let encryption: String?
  public let key: String?
  public let usesDefaultConfig: Bool?
  public let hidesSSID: Bool?
  public let wpsEnabled: Bool?
  enum CodingKeys: String, CodingKey {
    case enabled, ssid, encryption, key
    case usesDefaultConfig = "use_default_config"
    case hidesSSID = "hide_ssid"
    case wpsEnabled = "wps_enabled"
  }
}

public struct WifiBSS: Decodable, Identifiable, Sendable {
  public let id: String
  public let physicalID: FlexibleInt?
  public let status: WifiBSSStatus?
  public let config: WifiBSSConfig?
  enum CodingKeys: String, CodingKey {
    case id, status, config
    case physicalID = "phy_id"
  }
}

public struct WifiStation: Decodable, Identifiable, Sendable {
  public let id: String
  public let mac: String?
  public let bssid: String?
  public let hostname: String?
  public let state: String?
  public let inactiveSeconds: Int?
  public let connectionDuration: Int?
  public let receiveBytes: Int64?
  public let transmitBytes: Int64?
  public let receiveRate: Int64?
  public let transmitRate: Int64?
  public let signal: Int?
  enum CodingKeys: String, CodingKey {
    case id, mac, bssid, hostname, state, signal
    case inactiveSeconds = "inactive"
    case connectionDuration = "conn_duration"
    case receiveBytes = "rx_bytes"
    case transmitBytes = "tx_bytes"
    case receiveRate = "rx_rate"
    case transmitRate = "tx_rate"
  }
}

extension IliadboxClient {
  public func lanInterfaces() async throws -> [LanInterface] {
    try await authedCall("lan/browser/interfaces/")
  }
  public func lanHosts(interface: String) async throws -> [LanHost] {
    try await authedCall("lan/browser/\(Self.escapePathSegment(interface))")
  }
  public func updateLanHost(interface: String, id: String, name: String) async throws -> LanHost {
    struct Body: Encodable {
      let id: String
      let primaryName: String
      enum CodingKeys: String, CodingKey {
        case id
        case primaryName = "primary_name"
      }
    }
    return try await authedCall(
      "lan/browser/\(Self.escapePathSegment(interface))/\(Self.escapePathSegment(id))/",
      method: "PUT",
      jsonBody: Body(id: id, primaryName: name)
    )
  }

  public func dhcpStaticLeases() async throws -> [DhcpStaticLease] {
    try await authedCall("dhcp/static_lease/")
  }
  public func dhcpConfig() async throws -> DhcpConfig { try await authedCall("dhcp/config/") }
  public func addDhcpStaticLease(ip: String, mac: String) async throws -> DhcpStaticLease {
    struct Body: Encodable {
      let ip: String
      let mac: String
    }
    return try await authedCall(
      "dhcp/static_lease/", method: "POST", jsonBody: Body(ip: ip, mac: mac))
  }
  public func deleteDhcpStaticLease(id: String) async throws {
    let _: FbxEmpty = try await authedCall(
      "dhcp/static_lease/\(Self.escapePathSegment(id))", method: "DELETE")
  }

  public func wifiGlobalConfig() async throws -> WifiGlobalConfig {
    try await authedCall("wifi/config/")
  }
  public func setWifiEnabled(_ enabled: Bool) async throws -> WifiGlobalConfig {
    struct Body: Encodable { let enabled: Bool }
    return try await authedCall("wifi/config/", method: "PUT", jsonBody: Body(enabled: enabled))
  }
  public func wifiAccessPoints() async throws -> [WifiAccessPoint] {
    try await authedCall("wifi/ap/")
  }
  public func wifiBSSList() async throws -> [WifiBSS] { try await authedCall("wifi/bss/") }
  public func setWifiBSSEnabled(id: String, enabled: Bool) async throws -> WifiBSS {
    struct Configuration: Encodable { let enabled: Bool }
    struct Body: Encodable { let config: Configuration }
    return try await authedCall(
      "wifi/bss/\(Self.escapePathSegment(id))", method: "PUT",
      jsonBody: Body(config: Configuration(enabled: enabled))
    )
  }
  public func setWifiBSSWPS(id: String, enabled: Bool) async throws -> WifiBSS {
    struct Configuration: Encodable {
      let wpsEnabled: Bool
      enum CodingKeys: String, CodingKey { case wpsEnabled = "wps_enabled" }
    }
    struct Body: Encodable { let config: Configuration }
    return try await authedCall(
      "wifi/bss/\(Self.escapePathSegment(id))", method: "PUT",
      jsonBody: Body(config: Configuration(wpsEnabled: enabled))
    )
  }
  public func wifiStations(accessPointID: Int) async throws -> [WifiStation] {
    try await authedCall("wifi/ap/\(accessPointID)/stations/")
  }
}
