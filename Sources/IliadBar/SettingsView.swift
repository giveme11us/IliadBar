import IliadboxKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    TabView {
      GeneralSettingsView(model: model)
        .tabItem { Label("Generali", systemImage: "gearshape") }
      BoxSettingsView(model: model)
        .tabItem { Label("iliadbox", systemImage: "network") }
      NotificationSettingsView(model: model)
        .tabItem { Label("Notifiche", systemImage: "bell") }
      DiagnosticsSettingsView(model: model)
        .tabItem { Label("Diagnostica", systemImage: "stethoscope") }
    }
    .padding(20)
    .frame(width: 560, height: 430)
  }
}

private struct DiagnosticsSettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Form {
      Section("Supporto") {
        Text("Esporta un riepilogo tecnico utile per segnalare problemi.")
        Button {
          Task { await model.exportDiagnostics() }
        } label: {
          Label("Esporta diagnostica…", systemImage: "square.and.arrow.up")
        }
      }
      Section("Privacy") {
        Label(
          "Token, sessioni, URL della box, indirizzi IP e MAC, nomi dei dispositivi e chiavi Wi‑Fi non vengono inclusi.",
          systemImage: "lock.shield"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

private struct GeneralSettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Form {
      Section("Box attiva") {
        Picker(
          "iliadbox",
          selection: Binding(
            get: { model.activeProfileID ?? "" },
            set: { model.selectProfile($0) }
          )
        ) {
          if model.profiles.isEmpty {
            Text("Nessuna box configurata").tag("")
          }
          ForEach(model.profiles) { profile in
            Text(profile.name).tag(profile.id)
          }
        }
      }

      Section("Aggiornamento") {
        Stepper(
          "Durante i download: \(model.preferences.activeRefreshSeconds) s",
          value: Binding(
            get: { model.preferences.activeRefreshSeconds },
            set: { value in model.updatePreferences { $0.activeRefreshSeconds = value } }
          ),
          in: 2...30
        )
        Stepper(
          "A riposo: \(model.preferences.idleRefreshSeconds) s",
          value: Binding(
            get: { model.preferences.idleRefreshSeconds },
            set: { value in model.updatePreferences { $0.idleRefreshSeconds = value } }
          ),
          in: 10...300,
          step: 5
        )
        Text("La cadenza aumenta automaticamente quando un download è attivo.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section("macOS") {
        Toggle(
          "Avvia IliadBar al login",
          isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
          ))
      }
    }
    .formStyle(.grouped)
  }
}

private struct BoxSettingsView: View {
  @ObservedObject var model: AppModel
  @State private var manualName = "iliadbox"
  @State private var manualURL = BoxProfile.defaultBaseURL
  @State private var pendingRemoval: BoxProfile?

  var body: some View {
    Form {
      Section("Trovate sulla rete") {
        if model.discoveredBoxes.isEmpty {
          HStack {
            ProgressView()
              .controlSize(.small)
            Text(discoveryCopy)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Cerca di nuovo") { model.startDiscovery() }
          }
        } else {
          ForEach(model.discoveredBoxes) { box in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(box.name)
                Text(DiscoveryPresentation.detailLabel(box))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if model.profiles.contains(where: { $0.id == box.id }) {
                Button("Seleziona") { model.selectProfile(box.id) }
              } else {
                Button("Aggiungi") { model.useDiscoveredBox(box) }
              }
            }
          }
        }
      }

      Section("Configurazione manuale") {
        TextField("Nome", text: $manualName)
        TextField("URL API", text: $manualURL)
          .textFieldStyle(.roundedBorder)
        HStack {
          Text("Usala solo se Bonjour non trova la box.")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Aggiungi box") {
            model.addManualBox(name: manualName, baseURL: manualURL)
          }
          .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }

      if !model.profiles.isEmpty {
        Section("Box salvate") {
          ForEach(model.profiles) { profile in
            HStack {
              Image(
                systemName: profile.id == model.activeProfileID ? "checkmark.circle.fill" : "circle"
              )
              .foregroundStyle(profile.id == model.activeProfileID ? Color.green : Color.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Text(profile.baseURL)
                  .font(.caption.monospaced())
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer()
              Button("Usa") { model.selectProfile(profile.id) }
                .disabled(profile.id == model.activeProfileID)
              Button(role: .destructive) {
                pendingRemoval = profile
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
              .accessibilityLabel("Rimuovi box")
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .confirmationDialog(
      "Rimuovere questa iliadbox?",
      isPresented: Binding(
        get: { pendingRemoval != nil },
        set: { if !$0 { pendingRemoval = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Rimuovi box e credenziale", role: .destructive) {
        guard let profile = pendingRemoval else { return }
        pendingRemoval = nil
        model.removeProfile(profile)
      }
      Button("Annulla", role: .cancel) { pendingRemoval = nil }
    } message: {
      Text(
        "Il profilo e il relativo token saranno rimossi da questo Mac. La box non viene modificata."
      )
    }
  }

  private var discoveryCopy: String {
    DiscoveryPresentation.stateLabel(model.discoveryState)
  }
}

private struct NotificationSettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Form {
      Section("Download") {
        Toggle(
          "Notifiche di IliadBar",
          isOn: Binding(
            get: { model.preferences.notificationsEnabled },
            set: { value in model.updatePreferences { $0.notificationsEnabled = value } }
          ))
        Toggle(
          "Avvio di un download",
          isOn: Binding(
            get: { model.preferences.notifyOnStart },
            set: { value in model.updatePreferences { $0.notifyOnStart = value } }
          )
        )
        .disabled(!model.preferences.notificationsEnabled)
        Toggle(
          "Completamento di un download",
          isOn: Binding(
            get: { model.preferences.notifyOnCompletion },
            set: { value in model.updatePreferences { $0.notifyOnCompletion = value } }
          )
        )
        .disabled(!model.preferences.notificationsEnabled)
        Toggle(
          "Download non riuscito",
          isOn: Binding(
            get: { model.preferences.notifyOnFailure },
            set: { value in model.updatePreferences { $0.notifyOnFailure = value } }
          )
        )
        .disabled(!model.preferences.notificationsEnabled)
        Text("Scegli quali eventi dei download generano una notifica.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
