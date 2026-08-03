import Foundation

public struct PortForwardingRule: Decodable, Identifiable, Sendable {
  public let id: Int
  public let enabled: Bool
  public let protocolName: String
  public let wanPortStart: FlexibleInt
  public let wanPortEnd: Int
  public let lanIP: String
  public let lanPort: Int
  public let hostname: String?
  public let sourceIP: String
  public let comment: String?
  enum CodingKeys: String, CodingKey {
    case id, enabled, hostname, comment
    case protocolName = "ip_proto"
    case wanPortStart = "wan_port_start"
    case wanPortEnd = "wan_port_end"
    case lanIP = "lan_ip"
    case lanPort = "lan_port"
    case sourceIP = "src_ip"
  }
}

public struct IncomingPort: Decodable, Identifiable, Sendable {
  public let id: String
  public let enabled: Bool
  public let active: Bool?
  public let type: String?
  public let port: Int
  public let minimumPort: Int?
  public let maximumPort: Int?
  public let readOnly: Bool?
  enum CodingKeys: String, CodingKey {
    case id, enabled, active, type
    case readOnly = "readonly"
    case port = "in_port"
    case minimumPort = "min_port"
    case maximumPort = "max_port"
  }
}

public struct SambaConfig: Decodable, Sendable {
  public let fileShareEnabled: Bool
  public let printShareEnabled: Bool?
  public let logonEnabled: Bool?
  public let logonUser: String?
  public let workgroup: String?
  enum CodingKeys: String, CodingKey {
    case fileShareEnabled = "file_share_enabled"
    case printShareEnabled = "print_share_enabled"
    case logonEnabled = "logon_enabled"
    case logonUser = "logon_user"
    case workgroup
  }
}

public struct FTPConfig: Decodable, Sendable {
  public let enabled: Bool
  public let allowAnonymous: Bool?
  public let allowAnonymousWrite: Bool?
  public let allowRemoteAccess: Bool?
  public let weakPassword: Bool?
  public let controlPort: Int?
  public let dataPort: Int?
  public let remoteDomain: String?
  enum CodingKeys: String, CodingKey {
    case enabled
    case allowAnonymous = "allow_anonymous"
    case allowAnonymousWrite = "allow_anonymous_write"
    case allowRemoteAccess = "allow_remote_access"
    case weakPassword = "weak_password"
    case controlPort = "port_ctrl"
    case dataPort = "port_data"
    case remoteDomain = "remote_domain"
  }
}

public struct UPnPIGDConfig: Decodable, Sendable {
  public let enabled: Bool
  public let version: Int?
}

public struct UPnPAVConfig: Decodable, Sendable { public let enabled: Bool }

public struct ConnectionConfiguration: Decodable, Sendable {
  public let respondsToPing: Bool?
  public let securePassword: Bool?
  public let remoteAccess: Bool?
  public let remoteAccessPort: Int?
  public let remoteAccessMinimumPort: Int?
  public let remoteAccessMaximumPort: Int?
  public let apiRemoteAccess: Bool?
  public let wakeOnLAN: Bool?
  public let allowTokenRequest: Bool?
  enum CodingKeys: String, CodingKey {
    case respondsToPing = "ping"
    case securePassword = "is_secure_pass"
    case remoteAccess = "remote_access"
    case remoteAccessPort = "remote_access_port"
    case remoteAccessMinimumPort = "remote_access_min_port"
    case remoteAccessMaximumPort = "remote_access_max_port"
    case apiRemoteAccess = "api_remote_access"
    case wakeOnLAN = "wol"
    case allowTokenRequest = "allow_token_request"
  }
}

public struct ParentalRule: Decodable, Identifiable, Sendable {
  public let id: Int
  public let macs: [String]
  public let hosts: [String]?
  public let description: String?
  public let forced: Bool?
  public let forcedMode: String?
  public let schedulingMode: String?
  public let filterState: String?
  public let nextChange: Int?
  enum CodingKeys: String, CodingKey {
    case id, macs, hosts, forced
    case description = "desc"
    case forcedMode = "forced_mode"
    case schedulingMode = "scheduling_mode"
    case filterState = "filter_state"
    case nextChange = "next_change"
  }
}

public enum ParentalAccessMode: String, CaseIterable, Codable, Sendable {
  case allowed
  case webonly
  case denied
}

public struct ParentalPlanning: Codable, Sendable {
  public let resolution: Int
  public let customDayRanges: [String]?
  public let mapping: [String]

  public init(resolution: Int, customDayRanges: [String]?, mapping: [String]) {
    self.resolution = resolution
    self.customDayRanges = customDayRanges
    self.mapping = mapping
  }
  enum CodingKeys: String, CodingKey {
    case resolution, mapping
    case customDayRanges = "cdayranges"
  }
}

public struct CallEntry: Decodable, Identifiable, Sendable {
  public let id: Int
  public let type: String
  public let timestamp: Int64
  public let number: String
  public let name: String?
  public let duration: Int?
  public let isNew: Bool?
  enum CodingKeys: String, CodingKey {
    case id, type, number, name, duration
    case timestamp = "datetime"
    case isNew = "new"
  }
}

public struct ContactEntry: Decodable, Identifiable, Sendable {
  public let id: Int
  public let displayName: String?
  public let firstName: String?
  public let lastName: String?
  public let company: String?
  enum CodingKeys: String, CodingKey {
    case id, company
    case displayName = "display_name"
    case firstName = "first_name"
    case lastName = "last_name"
  }
}

public struct PVRProgrammedRecord: Decodable, Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let subname: String?
  public let channelName: String?
  public let start: Int64
  public let end: Int64
  public let state: String?
  public let enabled: Bool?
  public let conflict: Bool?
  public let error: String?
  enum CodingKeys: String, CodingKey {
    case id, name, subname, start, end, state, enabled, conflict, error
    case channelName = "channel_name"
  }
}

public struct VPNClientStatus: Decodable, Sendable {
  public let enabled: Bool?
  public let activeVPN: String?
  public let activeDescription: String?
  public let type: String?
  public let state: String?
  public let lastError: String?
  public let lastUp: Int64?
  enum CodingKeys: String, CodingKey {
    case enabled, type, state
    case activeVPN = "active_vpn"
    case activeDescription = "active_vpn_description"
    case lastError = "last_error"
    case lastUp = "last_up"
  }
}

public struct VPNServer: Decodable, Identifiable, Sendable {
  public var id: String { name }
  public let name: String
  public let type: String
  public let state: String
  public let connectionCount: Int?
  public let authenticatedConnectionCount: Int?
  enum CodingKeys: String, CodingKey {
    case name, type, state
    case connectionCount = "connection_count"
    case authenticatedConnectionCount = "auth_connection_count"
  }
}

extension IliadboxClient {
  public func portForwardingRules() async throws -> [PortForwardingRule] {
    try await authedCall("fw/redir/")
  }
  public func addPortForwardingRule(
    protocolName: String, wanPort: Int, lanIP: String, lanPort: Int,
    sourceIP: String = "0.0.0.0", comment: String = ""
  ) async throws -> PortForwardingRule {
    struct Body: Encodable {
      let enabled = true
      let comment: String
      let lanPort: Int
      let wanPortEnd: Int
      let wanPortStart: Int
      let lanIP: String
      let protocolName: String
      let sourceIP: String
      enum CodingKeys: String, CodingKey {
        case enabled, comment
        case lanPort = "lan_port"
        case wanPortEnd = "wan_port_end"
        case wanPortStart = "wan_port_start"
        case lanIP = "lan_ip"
        case protocolName = "ip_proto"
        case sourceIP = "src_ip"
      }
    }
    return try await authedCall(
      "fw/redir/", method: "POST",
      jsonBody: Body(
        comment: comment, lanPort: lanPort, wanPortEnd: wanPort, wanPortStart: wanPort,
        lanIP: lanIP, protocolName: protocolName, sourceIP: sourceIP
      ))
  }
  public func setPortForwardingRuleEnabled(id: Int, enabled: Bool) async throws
    -> PortForwardingRule
  {
    struct Body: Encodable { let enabled: Bool }
    return try await authedCall("fw/redir/\(id)", method: "PUT", jsonBody: Body(enabled: enabled))
  }
  public func deletePortForwardingRule(id: Int) async throws {
    let _: FbxEmpty = try await authedCall("fw/redir/\(id)", method: "DELETE")
  }
  public func incomingPorts() async throws -> [IncomingPort] {
    try await authedCall("fw/incoming/")
  }

  public func sambaConfig() async throws -> SambaConfig { try await authedCall("netshare/samba/") }
  public func ftpConfig() async throws -> FTPConfig { try await authedCall("ftp/config/") }
  public func upnpIGDConfig() async throws -> UPnPIGDConfig {
    try await authedCall("upnpigd/config/")
  }
  public func upnpAVConfig() async throws -> UPnPAVConfig { try await authedCall("upnpav/config/") }
  public func connectionConfiguration() async throws -> ConnectionConfiguration {
    try await authedCall("connection/config/")
  }

  public func parentalRules() async throws -> [ParentalRule] {
    try await authedCall("parental/filter/")
  }
  public func parentalPlanning(ruleID: Int) async throws -> ParentalPlanning {
    try await authedCall("parental/filter/\(ruleID)/planning")
  }
  public func updateParentalPlanning(ruleID: Int, planning: ParentalPlanning) async throws
    -> ParentalPlanning
  {
    try await authedCall(
      "parental/filter/\(ruleID)/planning", method: "PUT", jsonBody: planning)
  }
  public func addParentalRule(
    macs: [String], description: String, forcedMode: ParentalAccessMode = .allowed
  ) async throws -> ParentalRule {
    struct Body: Encodable {
      let macs: [String]
      let description: String
      let forced = false
      let forcedMode: ParentalAccessMode
      enum CodingKeys: String, CodingKey {
        case macs, forced
        case description = "desc"
        case forcedMode = "forced_mode"
      }
    }
    return try await authedCall(
      "parental/filter/", method: "POST",
      jsonBody: Body(macs: macs, description: description, forcedMode: forcedMode))
  }
  public func deleteParentalRule(id: Int) async throws {
    let _: FbxEmpty = try await authedCall("parental/filter/\(id)", method: "DELETE")
  }
  public func callLog() async throws -> [CallEntry] { try await authedCall("call/log/") }
  public func contacts() async throws -> [ContactEntry] { try await authedCall("contact/") }
  public func pvrProgrammedRecords() async throws -> [PVRProgrammedRecord] {
    try await authedCall("pvr/programmed/")
  }
  public func vpnClientStatus() async throws -> VPNClientStatus {
    try await authedCall("vpn_client/status")
  }
  public func vpnServers() async throws -> [VPNServer] { try await authedCall("vpn/") }
}
