import SwiftUI

/// Scala tipografica dell'app. Prima ogni superficie sceglieva da sé corpo e
/// peso (`.system(size: 15, weight: .semibold)` sparsi ovunque): stessi ruoli
/// resi in modi diversi. Qui i ruoli hanno un nome.
extension Font {
  /// Titolo di una card o intestazione di identità.
  public static let iliadTitle = Font.system(size: 15, weight: .semibold)
  /// Titolo di una schermata dentro la finestra.
  public static let iliadScreenTitle = Font.system(size: 22, weight: .semibold)
  /// Numero grande: cifre a larghezza fissa, così non balla mentre cambia.
  public static let iliadMetric =
    Font.system(size: 21, weight: .semibold, design: .rounded).monospacedDigit()
  /// Numero di supporto, stessa famiglia del precedente.
  public static let iliadMetricSmall =
    Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
  /// Etichetta di sezione, da usare con `sectionLabel()`.
  public static let iliadSectionLabel = Font.system(size: 10, weight: .semibold)
}

extension View {
  /// Etichetta di sezione: maiuscoletto spaziato e colore secondario.
  /// Il testo arriva già scritto per esteso, la resa la decide qui.
  public func sectionLabel() -> some View {
    self
      .font(.iliadSectionLabel)
      .textCase(.uppercase)
      .tracking(0.6)
      .foregroundStyle(.secondary)
  }

  /// Contenitore delle card: un riquadro sobrio con bordo sottile, al posto
  /// del GroupBox di sistema che porta con sé un look più pesante.
  public func iliadCard(padding: CGFloat = 16) -> some View {
    self
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.primary.opacity(0.045))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
      )
  }
}

/// Velatura dell'identità dietro al pannello: un accenno di rosso iliad che
/// sfuma subito, quanto basta a non far sembrare il pannello una finestra
/// vuota. Sta sopra il materiale del popover, non lo sostituisce.
public struct IliadPanelBackdrop: View {
  public init() {}

  public var body: some View {
    LinearGradient(
      stops: [
        .init(color: IliadPalette.red.opacity(0.10), location: 0),
        .init(color: IliadPalette.red.opacity(0.03), location: 0.22),
        .init(color: .clear, location: 0.5),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
