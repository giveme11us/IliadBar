import AppKit
import IliadBarDesign
import IliadboxKit
import SwiftUI

/// Configurazione iniziale: occupa la finestra intera perché è il momento in
/// cui si insegna che la finestra esiste (PRD-ONBOARDING §2).
struct OnboardingView: View {
  @ObservedObject var model: AppModel
  @State private var step: Step = .welcome
  @State private var manualName = "iliadbox"
  @State private var manualURL = BoxProfile.defaultBaseURL
  @State private var showManualEntry = false
  @State private var pairingFailed: String?

  enum Step: Int, CaseIterable {
    case welcome, discovery, pairing, permissions, done
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        content
          .padding(.horizontal, 40)
          .padding(.vertical, 28)
          .frame(maxWidth: 620, alignment: .leading)
          .frame(maxWidth: .infinity)
      }
      Divider()
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .transientFeedback(model)
  }

  // MARK: Intestazione e piede

  private var header: some View {
    HStack(spacing: 10) {
      ForEach(Step.allCases, id: \.rawValue) { candidate in
        Capsule()
          .fill(
            candidate.rawValue <= step.rawValue
              ? IliadPalette.red : Color.primary.opacity(0.12)
          )
          .frame(height: 3)
      }
    }
    .padding(.horizontal, 40)
    .padding(.vertical, 14)
    .accessibilityLabel("Passo \(step.rawValue + 1) di \(Step.allCases.count)")
  }

  private var footer: some View {
    HStack {
      if step != .welcome, step != .done {
        Button("Indietro") { back() }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Salta la configurazione") { model.completeOnboarding() }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.secondary)
      primaryButton
    }
    .padding(.horizontal, 40)
    .padding(.vertical, 14)
  }

  @ViewBuilder
  private var primaryButton: some View {
    switch step {
    case .welcome:
      Button("Iniziamo") { step = .discovery }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .keyboardShortcut(.defaultAction)
    case .discovery:
      Button("Continua") { step = .pairing }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .disabled(model.activeProfileID == nil)
        .keyboardShortcut(.defaultAction)
    case .pairing:
      if model.paired {
        Button("Continua") {
          step = .permissions
          Task { await model.refreshPermissions() }
        }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .keyboardShortcut(.defaultAction)
      } else {
        Button(model.pairingInProgress ? "In attesa…" : "Associa questo Mac") {
          pairingFailed = nil
          Task {
            await model.pair()
            if model.paired {
              step = .permissions
              await model.refreshPermissions()
            } else {
              pairingFailed = model.statusLine
            }
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .disabled(model.pairingInProgress)
        .keyboardShortcut(.defaultAction)
      }
    case .permissions:
      Button("Continua") { step = .done }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .keyboardShortcut(.defaultAction)
    case .done:
      Button("Apri IliadBar") { model.completeOnboarding() }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .keyboardShortcut(.defaultAction)
    }
  }

  private func back() {
    step = Step(rawValue: max(0, step.rawValue - 1)) ?? .welcome
  }

  // MARK: Contenuto

  @ViewBuilder
  private var content: some View {
    switch step {
    case .welcome: welcome
    case .discovery: discovery
    case .pairing: pairing
    case .permissions: permissions
    case .done: done
    }
  }

  private var welcome: some View {
    VStack(alignment: .leading, spacing: 18) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 84, height: 84)
      Text("Benvenuto in IliadBar")
        .font(.system(size: 26, weight: .semibold))
      Text("La tua iliadbox nella barra dei menu: stato della linea, download, file e rete.")
        .font(.title3)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: 12) {
        promise(
          icon: "lock.laptopcomputer", title: "Resta tutto sul tuo Mac",
          detail:
            "IliadBar parla direttamente con la box. Nessun servizio in mezzo, nessuna telemetria."
        )
        promise(
          icon: "bolt.horizontal", title: "Nativa e immediata",
          detail: "Swift e SwiftUI, nessuna dipendenza: si apre dalla barra dei menu quando serve.")
        promise(
          icon: "slider.horizontal.3", title: "Completa",
          detail:
            "Download, file, dispositivi, Wi-Fi e servizi avanzati, per quanto la tua box li espone."
        )
      }
      .padding(.top, 4)
    }
  }

  private func promise(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey)
    -> some View
  {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(IliadPalette.red)
        .frame(width: 26)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).fontWeight(.medium)
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var discovery: some View {
    VStack(alignment: .leading, spacing: 16) {
      stepTitle("Trova la tua iliadbox", subtitle: "Cerco sulla rete locale con Bonjour.")

      if model.discoveredBoxes.isEmpty {
        HStack(spacing: 9) {
          if case .searching = model.discoveryState {
            ProgressView().controlSize(.small)
          }
          Text(DiscoveryPresentation.stateLabel(model.discoveryState))
            .foregroundStyle(.secondary)
          Spacer()
          Button("Cerca di nuovo") { model.startDiscovery() }
        }
      } else {
        ForEach(model.discoveredBoxes) { box in
          Button {
            model.useDiscoveredBox(box)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "wifi.router.fill")
                .font(.title3)
                .foregroundStyle(IliadPalette.red)
                .frame(width: 28)
              VStack(alignment: .leading, spacing: 2) {
                Text(box.name).fontWeight(.medium)
                Text(DiscoveryPresentation.detailLabel(box))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Image(
                systemName: model.activeProfileID == box.id
                  ? "checkmark.circle.fill" : "circle"
              )
              .foregroundStyle(
                model.activeProfileID == box.id ? IliadTint.online : Color.secondary)
            }
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(model.activeProfileID == box.id ? 0.08 : 0.04))
            )
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }

      DisclosureGroup(isExpanded: $showManualEntry) {
        VStack(alignment: .leading, spacing: 10) {
          Text(
            "Succede se il Mac è su una rete diversa dalla box, con una VPN attiva o su una VLAN che blocca Bonjour."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          TextField("Nome", text: $manualName)
          TextField("URL API", text: $manualURL)
          Button("Usa questo indirizzo") {
            model.addManualBox(name: manualName, baseURL: manualURL)
          }
          .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, 8)
      } label: {
        Text("Non compare la tua box?")
      }
      .padding(.top, 4)
    }
    .task { model.startDiscovery() }
  }

  private var pairing: some View {
    VStack(alignment: .leading, spacing: 16) {
      stepTitle(
        "Autorizza IliadBar sulla box",
        subtitle:
          "L'associazione richiede una conferma fisica: è ciò che impedisce a chiunque altro sulla rete di comandare la tua box."
      )

      VStack(alignment: .leading, spacing: 14) {
        instruction(
          number: 1, text: "Premi «Associa questo Mac» qui sotto.")
        instruction(
          number: 2, text: "Vai alla iliadbox: sul display comparirà la richiesta di IliadBar.")
        instruction(
          number: 3, text: "Conferma sulla box. La richiesta scade dopo qualche minuto.")
      }

      if model.pairingInProgress {
        HStack(spacing: 9) {
          ProgressView().controlSize(.small)
          Text("In attesa della conferma sulla iliadbox")
            .fontWeight(.medium)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(IliadPalette.amber.opacity(0.10))
        )
      }

      if model.paired {
        Label("Associazione completata", systemImage: "checkmark.seal.fill")
          .foregroundStyle(IliadTint.online)
          .fontWeight(.medium)
      } else if let pairingFailed {
        VStack(alignment: .leading, spacing: 6) {
          Label("Associazione non riuscita", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(IliadPalette.red)
            .fontWeight(.medium)
          Text(pairingFailed)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func instruction(number: Int, text: LocalizedStringKey) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)")
        .font(.callout.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Circle().fill(IliadPalette.red))
      Text(text)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var permissions: some View {
    VStack(alignment: .leading, spacing: 16) {
      stepTitle(
        "Cosa può fare IliadBar",
        subtitle:
          "Sono i permessi che la box ha concesso a questo Mac. Quelli mancanti si aggiungono dall'interfaccia web della box."
      )

      VStack(spacing: 0) {
        ForEach(PermissionRow.all, id: \.key) { row in
          HStack(spacing: 12) {
            Image(
              systemName: model.permissions[row.key] == true
                ? "checkmark.circle.fill" : "lock.fill"
            )
            .foregroundStyle(
              model.permissions[row.key] == true ? IliadTint.online : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
              Text(row.title).fontWeight(.medium)
              Text(model.permissions[row.key] == true ? row.granted : row.missing)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
          }
          .padding(.vertical, 8)
          .accessibilityElement(children: .combine)
          if row.key != PermissionRow.all.last?.key { Divider() }
        }
      }

      HStack(spacing: 10) {
        Button("Apri le impostazioni della box") { model.openBoxWebInterface() }
        Button("Ricontrolla") { Task { await model.refreshPermissions() } }
      }
    }
    .task { await model.refreshPermissions() }
  }

  private var done: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label("Tutto pronto", systemImage: "checkmark.seal.fill")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(IliadTint.online)
      Text("IliadBar vive nella barra dei menu: l'icona in alto apre il pannello.")
        .font(.title3)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 14) {
        discoveryTip(
          icon: "link.badge.plus", title: "Link magnet",
          detail: "Apri i magnet direttamente sulla box invece che in un client sul Mac."
        ) {
          Button("Usa IliadBar per i magnet") { model.registerAsMagnetHandler() }
        }
        discoveryTip(
          icon: "square.grid.2x2", title: "Widget",
          detail: "Connessione e download nel Centro Notifiche, senza aprire l'app."
        ) {
          EmptyView()
        }
        discoveryTip(
          icon: "terminal", title: "Riga di comando",
          detail: "Il comando ibx espone stato, download e file in JSON per le automazioni."
        ) {
          Button("Copia il comando di installazione") { model.copyCLIInstallCommand() }
        }
      }

      Toggle(
        "Avvia IliadBar al login",
        isOn: Binding(
          get: { model.launchAtLogin },
          set: { model.setLaunchAtLogin($0) }
        )
      )
      .padding(.top, 4)
    }
  }

  private func discoveryTip(
    icon: String, title: LocalizedStringKey, detail: LocalizedStringKey,
    @ViewBuilder action: () -> some View
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(IliadPalette.red)
        .frame(width: 26)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).fontWeight(.medium)
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        action()
      }
    }
  }

  private func stepTitle(_ title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.system(size: 22, weight: .semibold))
      Text(subtitle)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Righe della schermata permessi: chiave API, cosa abilita, cosa si perde.
private struct PermissionRow {
  let key: String
  let title: LocalizedStringKey
  let granted: LocalizedStringKey
  let missing: LocalizedStringKey

  /// Proprietà calcolata e non costante: LocalizedStringKey non è Sendable,
  /// e uno stato globale immutabile qui non serve.
  static var all: [PermissionRow] {
    [
      PermissionRow(
        key: "downloader", title: "Download",
        granted: "Puoi aggiungere, mettere in pausa e rimuovere i download.",
        missing: "Senza questo permesso la sezione Download resta vuota."),
      PermissionRow(
        key: "explorer", title: "File",
        granted: "Puoi sfogliare i dischi della box, caricare e scaricare.",
        missing: "Senza questo permesso non puoi vedere i file della box."),
      PermissionRow(
        key: "settings", title: "Impostazioni",
        granted: "Puoi modificare Wi-Fi, DHCP e regole di rete.",
        missing: "Rete e servizi restano in sola lettura."),
      PermissionRow(
        key: "parental", title: "Controllo parentale",
        granted: "Puoi creare profili e cambiare le pianificazioni.",
        missing: "Le pianificazioni sono visibili ma non modificabili."),
      PermissionRow(
        key: "calls", title: "Chiamate",
        granted: "Il registro chiamate della box è disponibile.",
        missing: "La sezione Chiamate resta vuota."),
    ]
  }
}
