import AppKit
import Combine
import IliadboxKit
import Sparkle
import SwiftUI

@main
struct IliadBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    MenuBarExtra(
      "IliadBar",
      systemImage: "externaldrive.connected.to.line.below",
      isInserted: .constant(false)
    ) {
      EmptyView()
    }

    Settings {
      SettingsView(model: delegate.model)
    }

    // Una sola finestra di gestione: le sezioni vivono nel suo sidebar
    // (PRD-UX §2). Le Impostazioni restano la finestra Settings nativa.
    Window("IliadBar", id: IliadBarWindow.main) {
      MainWindowView(model: delegate.model)
    }
    .defaultSize(width: 1060, height: 680)
    .commands { IliadBarCommands(model: delegate.model) }
  }
}

enum IliadBarWindow {
  static let main = "main"
}

private struct IliadBarCommands: Commands {
  @ObservedObject var model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandMenu("IliadBar") {
      Button("Home") { open(.home) }.keyboardShortcut("1")
      Button("Download") { open(.download) }.keyboardShortcut("2")
      Button("File") { open(.file) }.keyboardShortcut("3")
      Button("Dispositivi") { open(.devices) }.keyboardShortcut("4")
      Button("Porte e NAT") { open(.nat) }.keyboardShortcut("5")
      Divider()
      Button("Aggiorna") { Task { await model.refresh() } }.keyboardShortcut("r")
    }
  }

  private func open(_ section: MainSection) {
    model.mainWindowSection = section
    openWindow(id: IliadBarWindow.main)
  }
}

/// Icona in menu bar + percentuale aggregata quando ci sono download attivi:
/// il dato vive accanto all'icona, il dettaglio nel pannello.
struct MenuBarLabel: View {
  @ObservedObject var model: AppModel

  var body: some View {
    if let percent = model.menuBarPercent {
      HStack(spacing: 3) {
        MenuBarGlyph(crossed: false).frame(width: 17, height: 17)
        Text(percent).monospacedDigit()
      }
    } else {
      MenuBarGlyph(crossed: !model.availability.isOnline && model.paired)
        .frame(width: 18, height: 18)
        .accessibilityLabel(model.availability.isOnline ? "IliadBar online" : "IliadBar offline")
    }
  }
}

private struct MenuBarGlyph: View {
  let crossed: Bool

  var body: some View {
    ZStack {
      IliadBarMark().stroke(lineWidth: 1.35)
      if crossed {
        Path { path in
          path.move(to: .init(x: 3, y: 3))
          path.addLine(to: .init(x: 15, y: 15))
        }
        .stroke(lineWidth: 1.5)
      }
    }
  }
}

/// Marchio monocromatico template-safe: gateway + impulso + flusso in uscita.
/// È disegnato a runtime per rimanere nitido su ogni scala della menu bar.
private struct IliadBarMark: Shape {
  func path(in rect: CGRect) -> Path {
    let scaleX = rect.width / 18
    let scaleY = rect.height / 18
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x * scaleX, y: y * scaleY) }
    var path = Path()
    path.addRoundedRect(
      in: CGRect(x: 2 * scaleX, y: 6 * scaleY, width: 14 * scaleX, height: 9 * scaleY),
      cornerSize: CGSize(width: 2.4 * scaleX, height: 2.4 * scaleY)
    )
    path.move(to: point(5, 6))
    path.addLine(to: point(5, 4))
    path.move(to: point(9, 6))
    path.addLine(to: point(9, 2))
    path.move(to: point(13, 6))
    path.addLine(to: point(13, 4))
    path.move(to: point(9, 4))
    path.addLine(to: point(9, 12))
    path.move(to: point(6.5, 9.5))
    path.addLine(to: point(9, 12))
    path.addLine(to: point(11.5, 9.5))
    return path
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel()
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )
  private let popover = NSPopover()
  private var statusItem: NSStatusItem?
  private var cancellables: Set<AnyCancellable> = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.autosaveName = "IliadBarStatusItem"
    statusItem = item
    NSLog("IliadBar status item registered (button: %@)", item.button == nil ? "no" : "yes")
    if let button = item.button {
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.imagePosition = .imageLeading
    }

    popover.behavior = .transient
    popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    popover.contentSize = NSSize(width: 380, height: 560)
    popover.contentViewController = NSHostingController(rootView: PanelView(model: model))

    model.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        DispatchQueue.main.async { self?.updateStatusItem() }
      }
      .store(in: &cancellables)
    updateStatusItem()
    // Restore only after the status item exists. Current profiles read the
    // private config immediately; legacy profiles may still require a one-time
    // Keychain migration dialog, which must never block app presentation.
    Task { await model.activateSavedCredential() }
  }

  /// Sinistro: pannello. Destro (o ctrl-click): menu contestuale, come ogni
  /// altra icona della menu bar di macOS.
  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    let isSecondaryClick =
      event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
    if isSecondaryClick {
      presentContextMenu(from: sender)
    } else {
      togglePopover(sender)
    }
  }

  private func togglePopover(_ sender: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(sender)
    } else {
      popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
      popover.contentViewController?.view.window?.makeKey()
    }
  }

  private func presentContextMenu(from button: NSStatusBarButton) {
    if popover.isShown { popover.performClose(nil) }
    let menu = NSMenu()
    menu.addItem(
      withTitle: String(localized: "Apri IliadBar"), action: #selector(openMainWindow),
      keyEquivalent: "")
    menu.addItem(
      withTitle: String(localized: "Aggiungi magnet dagli appunti"),
      action: #selector(addMagnetFromPasteboard), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: String(localized: "Impostazioni…"), action: #selector(openSettings),
      keyEquivalent: ",")
    menu.addItem(
      withTitle: String(localized: "Controlla aggiornamenti"),
      action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: String(localized: "Esci"), action: #selector(quitApp), keyEquivalent: "q")
    for item in menu.items where item.action != nil { item.target = self }
    // Il menu si aggancia solo per questo click: dopo, il tasto sinistro
    // deve tornare a mostrare il pannello.
    statusItem?.menu = menu
    button.performClick(nil)
    statusItem?.menu = nil
  }

  @objc private func openMainWindow() {
    model.mainWindowSection = .home
    NSApp.activate(ignoringOtherApps: true)
    // Una Window scene di SwiftUI si apre da openWindow o dalla voce di menu
    // che SwiftUI stessa costruisce: da AppKit resta la seconda strada.
    if !performMainMenuItem(titled: String(localized: "Home")), let button = statusItem?.button,
      !popover.isShown
    {
      togglePopover(button)
    }
  }

  private func performMainMenuItem(titled title: String) -> Bool {
    guard let mainMenu = NSApp.mainMenu else { return false }
    for top in mainMenu.items {
      guard let submenu = top.submenu,
        let item = submenu.items.first(where: { $0.title == title }),
        let action = item.action
      else { continue }
      return NSApp.sendAction(action, to: item.target, from: item)
    }
    return false
  }

  @objc private func addMagnetFromPasteboard() {
    Task { await model.addFromPasteboard() }
  }

  @objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    // Il selettore è cambiato in macOS 13: si prova il nuovo e si ricade sul
    // vecchio senza assumere la versione di sistema.
    if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
      NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
  }

  @objc private func checkForUpdatesFromMenu() {
    updaterController.checkForUpdates(nil)
  }

  @objc private func quitApp() {
    NSApplication.shared.terminate(nil)
  }

  private func updateStatusItem() {
    guard let button = statusItem?.button else { return }
    button.image = makeStatusImage(crossed: !model.availability.isOnline && model.paired)
    if let percent = model.menuBarPercent {
      statusItem?.length = NSStatusItem.variableLength
      button.title = " \(percent)"
    } else {
      statusItem?.length = NSStatusItem.squareLength
      button.title = ""
    }
    let detail = model.statusLine ?? model.availability.label
    button.toolTip = "IliadBar · \(detail)"
    button.setAccessibilityLabel(
      model.availability.isOnline ? "IliadBar online" : "IliadBar offline")
  }

  private func makeStatusImage(crossed: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
      NSColor.black.setStroke()

      let gateway = NSBezierPath(
        roundedRect: NSRect(x: 2, y: 3, width: 14, height: 9),
        xRadius: 2.4,
        yRadius: 2.4
      )
      gateway.lineWidth = 1.35
      gateway.stroke()

      let details = NSBezierPath()
      details.lineWidth = 1.35
      details.move(to: NSPoint(x: 5, y: 12))
      details.line(to: NSPoint(x: 5, y: 14))
      details.move(to: NSPoint(x: 9, y: 12))
      details.line(to: NSPoint(x: 9, y: 16))
      details.move(to: NSPoint(x: 13, y: 12))
      details.line(to: NSPoint(x: 13, y: 14))
      details.move(to: NSPoint(x: 9, y: 14))
      details.line(to: NSPoint(x: 9, y: 6))
      details.move(to: NSPoint(x: 6.5, y: 8.5))
      details.line(to: NSPoint(x: 9, y: 6))
      details.line(to: NSPoint(x: 11.5, y: 8.5))
      details.stroke()

      if crossed {
        let slash = NSBezierPath()
        slash.lineWidth = 1.5
        slash.move(to: NSPoint(x: 3, y: 15))
        slash.line(to: NSPoint(x: 15, y: 3))
        slash.stroke()
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  /// Punto d'ingresso dei link magnet: quando IliadBar è l'handler dello
  /// schema, LaunchServices consegna qui gli URL (anche ad app non avviata).
  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.scheme == "magnet" {
      Task { await model.add(magnet: url.absoluteString) }
    }
  }
}
