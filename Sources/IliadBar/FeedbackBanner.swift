import IliadBarDesign
import SwiftUI

/// Banner transiente con l'esito dell'ultima azione: compare in alto nella
/// finestra in cui l'utente sta lavorando e si dissolve da solo.
struct TransientFeedbackOverlay: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack {
      if let feedback = model.transientFeedback {
        HStack(spacing: 8) {
          Image(systemName: symbol(for: feedback.style))
            .foregroundStyle(color(for: feedback.style))
          Text(feedback.message)
            .lineLimit(2)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(color(for: feedback.style).opacity(0.35))
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
        .id(feedback.id)
        .accessibilityLabel(feedback.message)
      }
    }
    .animation(.easeOut(duration: 0.22), value: model.transientFeedback)
    .allowsHitTesting(false)
  }

  private func symbol(for style: TransientFeedback.Style) -> String {
    switch style {
    case .error: "exclamationmark.triangle.fill"
    case .success: "checkmark.circle.fill"
    case .info: "info.circle.fill"
    }
  }

  private func color(for style: TransientFeedback.Style) -> Color {
    switch style {
    case .error: IliadPalette.red
    case .success: IliadPalette.green
    case .info: IliadPalette.blue
    }
  }
}

extension View {
  /// Attacca alla finestra il banner degli esiti delle azioni.
  func transientFeedback(_ model: AppModel) -> some View {
    overlay(alignment: .top) { TransientFeedbackOverlay(model: model) }
  }
}
