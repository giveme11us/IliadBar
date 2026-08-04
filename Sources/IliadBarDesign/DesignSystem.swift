import AppKit
import SwiftUI

/// Palette IliadBar: unica fonte per app e widget. Il rosso iliad è
/// l'identità, i restanti sono colori semantici di stato e di misura.
///
/// Ogni tinta ha una variante chiara e una scura: gli stessi valori saturi
/// che funzionano su fondo bianco perdono leggibilità su fondo scuro.
public enum IliadPalette {
  public static let red = adaptive(
    light: (0.90, 0.00, 0.12), dark: (1.00, 0.32, 0.38), name: "iliadRed")
  public static let blue = adaptive(
    light: (0.12, 0.48, 0.96), dark: (0.40, 0.66, 1.00), name: "iliadBlue")
  public static let violet = adaptive(
    light: (0.48, 0.35, 0.91), dark: (0.66, 0.57, 1.00), name: "iliadViolet")
  public static let green = adaptive(
    light: (0.12, 0.68, 0.43), dark: (0.28, 0.82, 0.56), name: "iliadGreen")
  public static let amber = adaptive(
    light: (0.91, 0.57, 0.08), dark: (1.00, 0.72, 0.25), name: "iliadAmber")

  private static func adaptive(
    light: (Double, Double, Double), dark: (Double, Double, Double), name: String
  ) -> Color {
    Color(
      nsColor: NSColor(name: NSColor.Name(name)) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let components = isDark ? dark : light
        return NSColor(
          srgbRed: components.0, green: components.1, blue: components.2, alpha: 1)
      })
  }
}

/// Colori semantici condivisi: ogni superficie usa queste mappe, mai
/// colori di sistema scelti localmente.
public enum IliadTint {
  /// Stato raggiungibilità della box.
  public static let online = IliadPalette.green
  public static let offline = IliadPalette.red
  public static let connecting = IliadPalette.amber
  public static let stale = IliadPalette.amber

  /// Direzioni di traffico: download blu, upload rosso (identità iliad).
  public static let trafficDown = IliadPalette.blue
  public static let trafficUp = IliadPalette.red

  /// Tinta di un task download in base allo stato API.
  public static func downloadStatus(_ status: String?) -> Color {
    switch status {
    case "downloading", "starting": IliadPalette.blue
    case "done", "seeding": IliadPalette.green
    case "error": IliadPalette.red
    case "stopped": Color.secondary
    default: IliadPalette.amber
    }
  }
}
