import Foundation

/// Sezioni della finestra principale: un solo sidebar per tutta la gestione.
/// Su iOS le stesse sezioni alimentano la TabView.
enum MainSection: String, CaseIterable, Identifiable, Hashable {
  case home, download, file
  case devices, wifi, dhcp
  case nat, sharing, parental, communications, media
  var id: String { rawValue }
}
