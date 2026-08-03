import SwiftUI
import IliadboxKit

@main
struct MagnetBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("MagnetBox", systemImage: "arrow.down.circle") {
            MenuView(model: delegate.model)
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

struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.statusLine)
        Divider()
        Button("Aggiungi magnet dagli appunti") {
            Task { await model.addFromPasteboard() }
        }
        Button("Usa MagnetBox per i link magnet") {
            model.registerAsMagnetHandler()
        }
        Divider()
        Button("Esci") { NSApplication.shared.terminate(nil) }
    }
}
