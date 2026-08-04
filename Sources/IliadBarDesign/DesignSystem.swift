import SwiftUI

/// Palette IliadBar: unica fonte per app e widget. Il rosso iliad è
/// l'identità, i restanti sono colori semantici di stato e di misura.
public enum IliadPalette {
  public static let red = Color(red: 0.90, green: 0.00, blue: 0.12)
  public static let blue = Color(red: 0.12, green: 0.48, blue: 0.96)
  public static let violet = Color(red: 0.48, green: 0.35, blue: 0.91)
  public static let green = Color(red: 0.12, green: 0.68, blue: 0.43)
  public static let amber = Color(red: 0.91, green: 0.57, blue: 0.08)
}

/// Colori semantici condivisi: ogni superficie usa queste mappe, mai
/// colori di sistema scelti localmente.
public enum IliadTint {
  /// Stato raggiungibilità della box.
  public static let online = IliadPalette.green
  public static let offline = IliadPalette.red
  public static let connecting = IliadPalette.amber
  public static let stale = Color.orange

  /// Direzioni di traffico: download blu, upload rosso (identità iliad).
  public static let trafficDown = IliadPalette.blue
  public static let trafficUp = IliadPalette.red

  /// Tinta di un task download in base allo stato API.
  public static func downloadStatus(_ status: String?) -> Color {
    switch status {
    case "downloading", "starting": IliadPalette.blue
    case "done", "seeding": IliadPalette.green
    case "error": IliadPalette.red
    case "stopped": Color.gray
    default: IliadPalette.amber
    }
  }
}
