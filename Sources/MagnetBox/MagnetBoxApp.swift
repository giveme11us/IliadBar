import SwiftUI
import IliadboxKit

@main
struct MagnetBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Icona in menu bar + percentuale aggregata quando ci sono download attivi
/// (stile CodexBar: il dato vive accanto all'icona, il dettaglio nel pannello).
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let percent = model.menuBarPercent {
            Text("↓ \(percent)")
                .monospacedDigit()
        } else {
            Image(systemName: "arrow.down.circle")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    /// Punto d'ingresso dei link magnet: quando MagnetBox è l'handler dello
    /// schema, LaunchServices consegna qui gli URL (anche ad app non avviata).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "magnet" {
            Task { await model.add(magnet: url.absoluteString) }
        }
    }
}
