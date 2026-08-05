import SwiftUI

/// Ritratto della iliadbox: un disco (16,1 cm di diametro per 4,5 di altezza)
/// visto di tre quarti. È disegnato, non fotografato — resta nitido a ogni
/// scala, si adatta al tema chiaro e scuro e non porta con sé materiale
/// altrui. Il piano superiore resta neutro: il marchio non è nostro.
public struct IliadboxMark: View {
  /// Colora la spia sul fianco: verde online, rosso offline, ambra in
  /// transizione. `nil` la spegne (dispositivo non ancora associato).
  public var state: State?

  public enum State: Sendable {
    case online, offline, connecting
  }

  public init(state: State? = nil) {
    self.state = state
  }

  public var body: some View {
    GeometryReader { geometry in
      let width = min(geometry.size.width, geometry.size.height / 0.56)
      let topHeight = width * 0.40
      // 4,5 cm su 16,1 di diametro: il disco vero è sottile, e disegnarlo
      // spesso lo fa somigliare a un altro oggetto.
      let bodyHeight = width * 0.155
      let originX = (geometry.size.width - width) / 2
      let originY = (geometry.size.height - (topHeight + bodyHeight)) / 2

      ZStack(alignment: .topLeading) {
        // Ombra di appoggio: dà peso all'oggetto senza disegnare un piano.
        Ellipse()
          .fill(Color.black.opacity(0.13))
          .frame(width: width * 0.90, height: topHeight * 0.34)
          .blur(radius: width * 0.04)
          .offset(x: originX + width * 0.05, y: originY + topHeight * 0.86 + bodyHeight)

        // Fianco del disco: dal centro dell'ellisse superiore a quella inferiore.
        Path { path in
          let top = CGRect(x: originX, y: originY, width: width, height: topHeight)
          let bottom = top.offsetBy(dx: 0, dy: bodyHeight)
          path.addEllipse(in: bottom)
          path.addRect(
            CGRect(
              x: originX, y: originY + topHeight / 2, width: width, height: bodyHeight))
        }
        .fill(
          LinearGradient(
            colors: [Self.bodyLight, Self.bodyDark],
            startPoint: .leading,
            endPoint: .trailing)
        )

        // Piano superiore, appena più chiaro del fianco.
        Ellipse()
          .fill(
            LinearGradient(
              colors: [Self.topLight, Self.topDark],
              startPoint: .topLeading,
              endPoint: .bottomTrailing)
          )
          .frame(width: width, height: topHeight)
          .offset(x: originX, y: originY)

        // Bordo del piano: separa il coperchio dal fianco anche a 34 punti,
        // dove ogni altro dettaglio sparisce.
        Ellipse()
          .strokeBorder(Color.black.opacity(0.10), lineWidth: max(0.5, width * 0.008))
          .frame(width: width, height: topHeight)
          .offset(x: originX, y: originY)

        // Cerchio inciso: richiama la superficie del dispositivo senza
        // riprodurne il marchio.
        Ellipse()
          .strokeBorder(Color.black.opacity(0.07), lineWidth: max(0.5, width * 0.006))
          .frame(width: width * 0.52, height: topHeight * 0.52)
          .offset(x: originX + width * 0.24, y: originY + topHeight * 0.24)

        if let state {
          Capsule()
            .fill(Self.indicator(state))
            .frame(width: width * 0.10, height: max(2, bodyHeight * 0.22))
            .offset(
              x: originX + width * 0.45,
              y: originY + topHeight * 0.86 + bodyHeight * 0.45
            )
            .shadow(color: Self.indicator(state).opacity(0.7), radius: width * 0.03)
        }
      }
    }
    .aspectRatio(1.0 / 0.62, contentMode: .fit)
    .accessibilityHidden(true)
  }

  private static func indicator(_ state: State) -> Color {
    switch state {
    case .online: IliadTint.online
    case .offline: IliadTint.offline
    case .connecting: IliadTint.connecting
    }
  }

  // Bianco su fondo chiaro, grigio luminoso su fondo scuro: un bianco pieno
  // in dark mode diventa un buco di luce.
  private static let topLight = adaptive(light: 1.00, dark: 0.82)
  private static let topDark = adaptive(light: 0.93, dark: 0.70)
  private static let bodyLight = adaptive(light: 0.88, dark: 0.58)
  private static let bodyDark = adaptive(light: 0.74, dark: 0.42)

  private static func adaptive(light: Double, dark: Double) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let value = isDark ? dark : light
        return NSColor(srgbRed: value, green: value, blue: value * 0.995, alpha: 1)
      })
  }
}

#if DEBUG
  #Preview("iliadbox") {
    HStack(spacing: 24) {
      IliadboxMark(state: .online).frame(width: 120)
      IliadboxMark(state: .offline).frame(width: 60)
      IliadboxMark().frame(width: 34)
    }
    .padding(40)
  }
#endif
