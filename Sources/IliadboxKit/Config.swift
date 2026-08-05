import Foundation

/// Runtime client configuration used by the API client.
public struct IbxConfig: Codable, Sendable {
  public var boxID: String
  public var baseURL: String
  public var appToken: String?

  public init(
    boxID: String = BoxProfile.legacyID,
    baseURL: String = BoxProfile.defaultBaseURL,
    appToken: String? = nil
  ) {
    self.boxID = boxID
    self.baseURL = baseURL
    self.appToken = appToken
  }

  enum CodingKeys: String, CodingKey {
    case boxID, baseURL, appToken
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    boxID = try values.decodeIfPresent(String.self, forKey: .boxID) ?? BoxProfile.legacyID
    baseURL = try values.decodeIfPresent(String.self, forKey: .baseURL) ?? BoxProfile.defaultBaseURL
    appToken = try values.decodeIfPresent(String.self, forKey: .appToken)
  }
}

public struct BoxProfile: Codable, Identifiable, Hashable, Sendable {
  public static let legacyID = "default"
  public static let defaultBaseURL = "http://192.168.1.254/api/v15/"

  public var id: String
  public var name: String
  public var baseURL: String
  public var uid: String?
  public var deviceType: String?
  public var apiVersion: String?
  public var lastSeen: Date?
  /// Permanent pairing token. The configuration file is restricted to mode 0600.
  public var appToken: String?

  public init(
    id: String,
    name: String,
    baseURL: String,
    uid: String? = nil,
    deviceType: String? = nil,
    apiVersion: String? = nil,
    lastSeen: Date? = nil,
    appToken: String? = nil
  ) {
    self.id = id
    self.name = name
    self.baseURL = baseURL
    self.uid = uid
    self.deviceType = deviceType
    self.apiVersion = apiVersion
    self.lastSeen = lastSeen
    self.appToken = appToken
  }

  public static var legacy: BoxProfile {
    BoxProfile(id: legacyID, name: "iliadbox", baseURL: defaultBaseURL)
  }
}

public struct AppPreferences: Codable, Equatable, Sendable {
  public var idleRefreshSeconds: Int
  public var activeRefreshSeconds: Int
  public var notificationsEnabled: Bool
  public var notifyOnStart: Bool
  public var notifyOnCompletion: Bool
  public var notifyOnFailure: Bool

  public init(
    idleRefreshSeconds: Int = 20,
    activeRefreshSeconds: Int = 3,
    notificationsEnabled: Bool = true,
    notifyOnStart: Bool = true,
    notifyOnCompletion: Bool = true,
    notifyOnFailure: Bool = true
  ) {
    self.idleRefreshSeconds = idleRefreshSeconds
    self.activeRefreshSeconds = activeRefreshSeconds
    self.notificationsEnabled = notificationsEnabled
    self.notifyOnStart = notifyOnStart
    self.notifyOnCompletion = notifyOnCompletion
    self.notifyOnFailure = notifyOnFailure
  }

  enum CodingKeys: String, CodingKey {
    case idleRefreshSeconds, activeRefreshSeconds, notificationsEnabled
    case notifyOnStart, notifyOnCompletion, notifyOnFailure
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    idleRefreshSeconds = try values.decodeIfPresent(Int.self, forKey: .idleRefreshSeconds) ?? 20
    activeRefreshSeconds = try values.decodeIfPresent(Int.self, forKey: .activeRefreshSeconds) ?? 3
    notificationsEnabled =
      try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
    notifyOnStart = try values.decodeIfPresent(Bool.self, forKey: .notifyOnStart) ?? true
    notifyOnCompletion = try values.decodeIfPresent(Bool.self, forKey: .notifyOnCompletion) ?? true
    notifyOnFailure = try values.decodeIfPresent(Bool.self, forKey: .notifyOnFailure) ?? true
  }
}

public struct AppConfig: Codable, Sendable {
  public static let currentSchemaVersion = 3

  public var schemaVersion: Int
  public var activeBoxID: String?
  public var boxes: [BoxProfile]
  public var preferences: AppPreferences
  /// Configurazione iniziale conclusa (o saltata). Assente nei file scritti
  /// prima della 1.0: chi ha già una box viene considerato a posto.
  public var onboardingCompleted: Bool

  public init(
    schemaVersion: Int = currentSchemaVersion,
    activeBoxID: String? = nil,
    boxes: [BoxProfile] = [],
    preferences: AppPreferences = AppPreferences(),
    onboardingCompleted: Bool = false
  ) {
    self.schemaVersion = schemaVersion
    self.activeBoxID = activeBoxID
    self.boxes = boxes
    self.preferences = preferences
    self.onboardingCompleted = onboardingCompleted
  }

  enum CodingKeys: String, CodingKey {
    case schemaVersion, activeBoxID, boxes, preferences, onboardingCompleted
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    // Un file legacy (solo baseURL e appToken) non deve essere accettato qui:
    // decodificarlo come AppConfig vuota salterebbe la migrazione del token.
    guard values.contains(.schemaVersion) || values.contains(.boxes) else {
      throw DecodingError.keyNotFound(
        CodingKeys.schemaVersion,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Configurazione in formato legacy"))
    }
    schemaVersion =
      try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
    activeBoxID = try values.decodeIfPresent(String.self, forKey: .activeBoxID)
    boxes = try values.decodeIfPresent([BoxProfile].self, forKey: .boxes) ?? []
    preferences =
      try values.decodeIfPresent(AppPreferences.self, forKey: .preferences) ?? AppPreferences()
    // Aggiornamento da una versione precedente: chi ha già una box salvata ha
    // di fatto concluso la configurazione, e non deve rivederla.
    onboardingCompleted =
      try values.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? !boxes.isEmpty
  }

  public var activeBox: BoxProfile? {
    guard let activeBoxID else { return boxes.first }
    return boxes.first { $0.id == activeBoxID } ?? boxes.first
  }

  public mutating func removeBox(id: String) {
    boxes.removeAll { $0.id == id }
    if activeBoxID == id || !boxes.contains(where: { $0.id == activeBoxID }) {
      activeBoxID = boxes.first?.id
    }
  }
}

public enum ConfigStore {
  struct DecodedConfiguration {
    let appConfig: AppConfig
    let legacyToken: String?
    let wasLegacy: Bool
  }

  public static var directory: URL {
    if let override = ProcessInfo.processInfo.environment["ILIADBAR_CONFIG_DIRECTORY"],
      !override.isEmpty
    {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("IliadBar", isDirectory: true)
  }

  public static var fileURL: URL {
    directory.appendingPathComponent("config.json")
  }

  /// Loads the versioned configuration. Tokens are stored in this private file
  /// to avoid recurring Keychain prompts in local and CLI builds.
  public static func loadAppConfig() -> AppConfig {
    guard let data = try? Data(contentsOf: fileURL) else { return AppConfig() }
    guard let decoded = decodeConfiguration(data) else { return AppConfig() }
    guard decoded.wasLegacy else { return decoded.appConfig }
    var migrated = decoded.appConfig
    if let token = decoded.legacyToken, let profileID = migrated.activeBox?.id,
      let index = migrated.boxes.firstIndex(where: { $0.id == profileID })
    {
      migrated.boxes[index].appToken = token
    }
    try? saveAppConfig(migrated)
    return migrated
  }

  static func decodeConfiguration(_ data: Data) -> DecodedConfiguration? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let config = try? decoder.decode(AppConfig.self, from: data) {
      return DecodedConfiguration(appConfig: config, legacyToken: nil, wasLegacy: false)
    }
    guard let legacy = try? decoder.decode(IbxConfig.self, from: data) else { return nil }
    let profile = BoxProfile(
      id: legacy.boxID,
      name: "iliadbox",
      baseURL: legacy.baseURL
    )
    return DecodedConfiguration(
      appConfig: AppConfig(activeBoxID: profile.id, boxes: [profile]),
      legacyToken: legacy.appToken,
      wasLegacy: true
    )
  }

  /// Compatibility entry point used by the app and CLI. The interaction flag
  /// remains source-compatible but no longer triggers Keychain UI.
  public static func load(allowKeychainInteraction: Bool = true) -> IbxConfig {
    let app = loadAppConfig()
    let profile = app.activeBox ?? .legacy
    return IbxConfig(
      boxID: profile.id,
      baseURL: profile.baseURL,
      appToken: profile.appToken ?? legacyToken(profileID: profile.id)
    )
  }

  /// Saves the active runtime configuration. Existing profiles and preferences
  /// are preserved and the resulting file is restricted to the current user.
  public static func save(_ config: IbxConfig) throws {
    var app = loadAppConfig()
    let existing = app.boxes.first { $0.id == config.boxID }
    let profile = BoxProfile(
      id: config.boxID,
      name: existing?.name ?? "iliadbox",
      baseURL: config.baseURL,
      uid: existing?.uid,
      deviceType: existing?.deviceType,
      apiVersion: existing?.apiVersion,
      lastSeen: existing?.lastSeen,
      appToken: config.appToken ?? existing?.appToken
    )
    upsert(profile, in: &app)
    app.activeBoxID = profile.id
    try saveAppConfig(app)
  }

  public static func saveAppConfig(_ config: AppConfig) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var current = config
    current.schemaVersion = AppConfig.currentSchemaVersion
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(current)
    try data.write(to: fileURL, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
  }

  public static func setActiveBox(_ id: String) throws {
    var config = loadAppConfig()
    guard config.boxes.contains(where: { $0.id == id }) else { return }
    config.activeBoxID = id
    try saveAppConfig(config)
  }

  public static func saveProfile(_ profile: BoxProfile, makeActive: Bool = true) throws {
    var config = loadAppConfig()
    var updated = profile
    if updated.appToken == nil {
      updated.appToken = config.boxes.first(where: { $0.id == profile.id })?.appToken
    }
    upsert(updated, in: &config)
    if makeActive { config.activeBoxID = updated.id }
    try saveAppConfig(config)
  }

  public static func removeProfile(_ id: String) throws {
    var config = loadAppConfig()
    guard config.boxes.contains(where: { $0.id == id }) else { return }
    config.removeBox(id: id)
    try saveAppConfig(config)
  }

  private static func upsert(_ profile: BoxProfile, in config: inout AppConfig) {
    if let index = config.boxes.firstIndex(where: { $0.id == profile.id }) {
      config.boxes[index] = profile
    } else {
      config.boxes.append(profile)
    }
  }

  private static func legacyToken(profileID: String) -> String? {
    guard let data = try? Data(contentsOf: fileURL),
      let legacy = try? JSONDecoder().decode(IbxConfig.self, from: data),
      legacy.boxID == profileID
    else { return nil }
    return legacy.appToken
  }
}
