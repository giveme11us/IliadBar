import Foundation

public struct IliadBarWidgetSnapshot: Codable, Sendable {
  public let updatedAt: Date
  public let online: Bool
  public let downloadRate: Int64
  public let uploadRate: Int64
  public let activeDownloads: Int
  public let downloadProgress: Double?

  public init(
    updatedAt: Date = Date(), online: Bool, downloadRate: Int64,
    uploadRate: Int64, activeDownloads: Int, downloadProgress: Double?
  ) {
    self.updatedAt = updatedAt
    self.online = online
    self.downloadRate = downloadRate
    self.uploadRate = uploadRate
    self.activeDownloads = activeDownloads
    self.downloadProgress = downloadProgress
  }
}

public enum IliadBarWidgetSnapshotStore {
  public static var appGroup: String {
    Bundle.main.object(forInfoDictionaryKey: "IliadBarAppGroup") as? String
      ?? "group.it.ivansposato.iliadbar"
  }
  private static let key = "widget-snapshot-v1"

  public static func save(_ snapshot: IliadBarWidgetSnapshot) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    UserDefaults(suiteName: appGroup)?.set(data, forKey: key)
  }

  public static func load() -> IliadBarWidgetSnapshot? {
    guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(IliadBarWidgetSnapshot.self, from: data)
  }
}
