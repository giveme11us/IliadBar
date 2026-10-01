import IliadBarDesign
import IliadboxKit
import SwiftUI

/// Guscio iOS: le stesse sezioni della finestra unica macOS vivono in una
/// TabView; l'onboarding occupa lo schermo finché la box non è configurata.
@main
struct IliadBarApp: App {
  @StateObject private var model = AppModel()
  @State private var selectedTab: MainSection = .home

  var body: some Scene {
    WindowGroup {
      Group {
        if model.showingOnboarding {
          OnboardingView(model: model)
        } else {
          RootTabView(model: model, selection: $selectedTab)
        }
      }
      .transientFeedback(model)
      .task { await model.activateSavedCredential() }
      .onOpenURL { url in
        handle(url: url)
      }
      // Ponte con revealInFiles: il model cambia sezione e la tab segue.
      .onChange(of: model.mainWindowSection) { _, section in
        selectedTab = RootTabView.tab(for: section)
      }
    }
  }

  /// Ingressi URL: magnet (aggiunta diretta) e iliadbar://<sezione>
  /// (deep link dei widget).
  private func handle(url: URL) {
    switch url.scheme {
    case "magnet":
      Task { await model.add(magnet: url.absoluteString) }
    case "iliadbar":
      if let section = MainSection(rawValue: url.host() ?? "") {
        model.mainWindowSection = section
        selectedTab = RootTabView.tab(for: section)
      }
    default:
      break
    }
  }
}

struct RootTabView: View {
  @ObservedObject var model: AppModel
  @Binding var selection: MainSection

  var body: some View {
    TabView(selection: $selection) {
      NavigationStack {
        HomeView(model: model)
      }
      .tabItem { Label("Home", systemImage: "house") }
      .tag(MainSection.home)

      NavigationStack {
        DownloadManagerView(model: model)
      }
      .tabItem { Label("Download", systemImage: "arrow.down.circle") }
      .tag(MainSection.download)

      NavigationStack {
        FileManagerView(model: model)
      }
      .tabItem { Label("File", systemImage: "externaldrive") }
      .tag(MainSection.file)

      NavigationStack {
        NetworkHubView(model: model)
      }
      .tabItem { Label("Rete", systemImage: "wifi") }
      .tag(MainSection.devices)

      NavigationStack {
        SettingsView(model: model)
          .navigationTitle("Impostazioni")
          .navigationBarTitleDisplayMode(.inline)
      }
      .tabItem { Label("Impostazioni", systemImage: "gearshape") }
      .tag(MainSection.nat)
    }
  }

  /// Mappa sezione → tab: rete e servizi vivono insieme nell'hub Rete.
  static func tab(for section: MainSection) -> MainSection {
    switch section {
    case .home: .home
    case .download: .download
    case .file: .file
    case .devices, .wifi, .dhcp: .devices
    case .nat, .sharing, .parental, .communications, .media: .nat
    }
  }
}

/// Le sezioni Rete e Servizi avanzate della finestra unica, come elenco
/// navigabile: stesso contenuto, gerarchia da telefono.
struct NetworkHubView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    List {
      Section("Rete") {
        NavigationLink {
          NetworkView(model: model, section: .devices)
        } label: {
          Label("Dispositivi", systemImage: "desktopcomputer")
        }
        NavigationLink {
          NetworkView(model: model, section: .wifi)
        } label: {
          Label("Wi‑Fi", systemImage: "wifi")
        }
        NavigationLink {
          NetworkView(model: model, section: .dhcp)
        } label: {
          Label("DHCP", systemImage: "network")
        }
      }
      Section("Servizi") {
        NavigationLink {
          AdvancedServicesView(model: model, section: .nat)
        } label: {
          Label("Porte e NAT", systemImage: "arrow.triangle.branch")
        }
        NavigationLink {
          AdvancedServicesView(model: model, section: .services)
        } label: {
          Label("Condivisione", systemImage: "externaldrive.connected.to.line.below")
        }
        NavigationLink {
          AdvancedServicesView(model: model, section: .family)
        } label: {
          Label("Controllo parentale", systemImage: "figure.2.and.child.holdinghands")
        }
        NavigationLink {
          AdvancedServicesView(model: model, section: .communications)
        } label: {
          Label("Chiamate e contatti", systemImage: "phone")
        }
        NavigationLink {
          AdvancedServicesView(model: model, section: .media)
        } label: {
          Label("VPN e TV", systemImage: "play.tv")
        }
      }
    }
    .navigationTitle("Rete")
    .navigationBarTitleDisplayMode(.inline)
  }
}
