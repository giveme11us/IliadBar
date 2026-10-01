import SwiftUI

// MARK: - Barra di progresso (Canvas singolo: niente modificatori di compositing
// SwiftUI, che su macOS 26 possono rompere il rendering delle status item)

struct ProgressBarView: View {
  let percent: Double
  let tint: Color

  var body: some View {
    Canvas { context, size in
      let corner = CGSize(width: size.height / 2, height: size.height / 2)
      let rect = CGRect(origin: .zero, size: size)
      var track = Path()
      track.addRoundedRect(in: rect, cornerSize: corner)
      context.fill(track, with: .color(.primary.opacity(0.12)))

      let width = size.width * min(100, max(0, percent)) / 100
      if width > 0 {
        var fill = Path()
        fill.addRoundedRect(
          in: CGRect(x: 0, y: 0, width: width, height: size.height),
          cornerSize: corner
        )
        context.fill(fill, with: .color(tint))
      }
    }
    .frame(height: 5)
  }
}
