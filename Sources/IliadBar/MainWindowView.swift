import AppKit
import IliadBarDesign
import SwiftUI

/// Sezioni della finestra principale: un solo sidebar per tutta la gestione.
enum MainSection: String, CaseIterable, Identifiable, Hashable {
  case home, download, file
  case devices, wifi, dhcp
  case nat, sharing, parental, communications, media
  var id: String { rawValue }
}

/// La finestra unica di IliadBar: sidebar unificato + area di dettaglio.
/// Sostituisce le quattro finestre separate (PRD-UX §2).
struct MainWindowView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationSplitView {
      List(selection: sectionBinding) {
        Label("Home", systemImage: "house").tag(MainSection.home)
        Label("Download", systemImage: "arrow.down.circle").tag(MainSection.download)
        Label("File", systemImage: "externaldrive").tag(MainSection.file)
        Section("Rete") {
          Label("Dispositivi", systemImage: "desktopcomputer").tag(MainSection.devices)
          Label("Wi‑Fi", systemImage: "wifi").tag(MainSection.wifi)
          Label("DHCP", systemImage: "network").tag(MainSection.dhcp)
        }
        Section("Servizi") {
          Label("Porte e NAT", systemImage: "arrow.triangle.branch").tag(MainSection.nat)
          Label("Condivisione", systemImage: "externaldrive.connected.to.line.below")
            .tag(MainSection.sharing)
          Label("Controllo parentale", systemImage: "figure.2.and.child.holdinghands")
            .tag(MainSection.parental)
          Label("Chiamate e contatti", systemImage: "phone").tag(MainSection.communications)
          Label("VPN e TV", systemImage: "play.tv").tag(MainSection.media)
        }
      }
      .navigationSplitViewColumnWidth(min: 190, ideal: 210)
    } detail: {
      detail
    }
    .frame(minWidth: 980, minHeight: 620)
    .transientFeedback(model)
    // L'app vive in menu bar (LSUIElement): con la finestra aperta diventa
    // una app piena (icona in Dock, ⌘-Tab), alla chiusura torna accessoria.
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
    .onDisappear {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  private var sectionBinding: Binding<MainSection?> {
    Binding(
      get: { model.mainWindowSection },
      set: { model.mainWindowSection = $0 ?? .home }
    )
  }

  @ViewBuilder
  private var detail: some View {
    switch model.mainWindowSection {
    case .home:
      HomeView(model: model)
    case .download:
      DownloadManagerView(model: model)
    case .file:
      FileManagerView(model: model)
    case .devices:
      NetworkView(model: model, section: .devices)
    case .wifi:
      NetworkView(model: model, section: .wifi)
    case .dhcp:
      NetworkView(model: model, section: .dhcp)
    case .nat:
      AdvancedServicesView(model: model, section: .nat)
    case .sharing:
      AdvancedServicesView(model: model, section: .services)
    case .parental:
      AdvancedServicesView(model: model, section: .family)
    case .communications:
      AdvancedServicesView(model: model, section: .communications)
    case .media:
      AdvancedServicesView(model: model, section: .media)
    }
  }
}
