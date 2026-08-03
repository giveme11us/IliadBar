import IliadboxKit
import SwiftUI

private enum ServiceSection: String, CaseIterable, Identifiable {
  case nat, services, family, communications, media
  var id: String { rawValue }
  var title: LocalizedStringKey {
    switch self {
    case .nat: "Porte e NAT"
    case .services: "Condivisione"
    case .family: "Controllo parentale"
    case .communications: "Chiamate e contatti"
    case .media: "VPN e TV"
    }
  }
  var icon: String {
    switch self {
    case .nat: "arrow.triangle.branch"
    case .services: "externaldrive.connected.to.line.below"
    case .family: "figure.2.and.child.holdinghands"
    case .communications: "phone"
    case .media: "play.tv"
    }
  }
}

struct AdvancedServicesView: View {
  @ObservedObject var model: AppModel
  @State private var section: ServiceSection = .nat
  @State private var showAddRule = false
  @State private var pendingDeletion: PortForwardingRule?
  @State private var selectedParentalRule: ParentalRule?
  @State private var showAddParentalRule = false
  @State private var pendingParentalDeletion: ParentalRule?

  var body: some View {
    NavigationSplitView {
      List(ServiceSection.allCases, selection: $section) { item in
        Label(item.title, systemImage: item.icon).tag(item)
      }
      .navigationSplitViewColumnWidth(min: 170, ideal: 190)
    } detail: {
      Group {
        switch section {
        case .nat: nat
        case .services: services
        case .family: family
        case .communications: communications
        case .media: media
        }
      }
      .navigationTitle(section.title)
      .toolbar {
        ToolbarItem {
          Button {
            Task { await model.refreshAdvancedServices() }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help("Aggiorna servizi")
          .accessibilityLabel("Aggiorna servizi")
        }
      }
    }
    .frame(minWidth: 820, minHeight: 560)
    .task { await model.refreshAdvancedServices() }
    .sheet(isPresented: $showAddRule) {
      AddForwardingRuleSheet(model: model, isPresented: $showAddRule)
    }
    .confirmationDialog(
      "Eliminare la regola di port forwarding?",
      isPresented: Binding(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
      )
    ) {
      Button("Elimina regola", role: .destructive) {
        guard let rule = pendingDeletion else { return }
        pendingDeletion = nil
        Task { await model.deletePortForwarding(rule) }
      }
      Button("Annulla", role: .cancel) { pendingDeletion = nil }
    } message: {
      Text("Le connessioni che usano questa porta non raggiungeranno più il dispositivo interno.")
    }
    .sheet(item: $selectedParentalRule) { rule in
      ParentalPlanningSheet(model: model, rule: rule)
    }
    .sheet(isPresented: $showAddParentalRule) {
      AddParentalRuleSheet(model: model, isPresented: $showAddParentalRule)
    }
    .confirmationDialog(
      "Eliminare il profilo di controllo parentale?",
      isPresented: Binding(
        get: { pendingParentalDeletion != nil },
        set: { if !$0 { pendingParentalDeletion = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Elimina profilo", role: .destructive) {
        guard let rule = pendingParentalDeletion else { return }
        pendingParentalDeletion = nil
        Task { await model.deleteParentalRule(rule) }
      }
      Button("Annulla", role: .cancel) { pendingParentalDeletion = nil }
    } message: {
      Text("I dispositivi del profilo torneranno alla politica di accesso predefinita della box.")
    }
  }

  private var nat: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Port forwarding").font(.headline)
        if let range = model.connection?.assignedPortRange {
          Text("range pubblico \(range.lowerBound)–\(range.upperBound)")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          showAddRule = true
        } label: {
          Label("Nuova regola", systemImage: "plus")
        }
        .disabled(!model.networkSettingsAllowed || !model.advancedCapabilities.contains(.nat))
      }
      .padding()
      permissionNotice
      List {
        Section("Regole statiche") {
          if model.advancedCapabilities.contains(.nat) {
            ForEach(model.portForwardingRules) { rule in
              HStack(spacing: 12) {
                Toggle(
                  "",
                  isOn: Binding(
                    get: { rule.enabled },
                    set: { enabled in
                      Task { await model.setPortForwardingEnabled(rule, enabled: enabled) }
                    }
                  )
                )
                .labelsHidden().disabled(!model.networkSettingsAllowed)
                VStack(alignment: .leading, spacing: 3) {
                  Text(
                    rule.comment?.isEmpty == false
                      ? rule.comment! : (rule.hostname ?? "Regola \(rule.id)"))
                  Text(
                    "\(rule.protocolName.uppercased()) · :\(rule.wanPortStart.intValue) → \(rule.lanIP):\(rule.lanPort)"
                  )
                  .font(.caption).foregroundStyle(.secondary).monospacedDigit().textSelection(
                    .enabled)
                }
                Spacer()
                Button(role: .destructive) {
                  pendingDeletion = rule
                } label: {
                  Image(systemName: "trash")
                }
                .buttonStyle(.borderless).disabled(!model.networkSettingsAllowed)
                .accessibilityLabel("Elimina regola")
              }
            }
          } else {
            unavailable("Port forwarding")
          }
        }
        Section("Porte gestite dai servizi") {
          if model.advancedCapabilities.contains(.incomingPorts) {
            ForEach(model.incomingPorts) { port in
              HStack {
                Circle().fill(port.active == true ? Color.green : Color.secondary).frame(
                  width: 7, height: 7)
                Text(serviceName(port.id))
                Spacer()
                Text("\(port.type?.uppercased() ?? "") · \(port.port)")
                  .font(.caption).foregroundStyle(.secondary).monospacedDigit()
              }
            }
          } else {
            unavailable("Porte in ingresso")
          }
        }
      }
    }
  }

  private var services: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        serviceCard(
          "Condivisione SMB", icon: "externaldrive.badge.wifi",
          available: model.advancedCapabilities.contains(.samba),
          enabled: model.sambaConfig?.fileShareEnabled,
          details: [model.sambaConfig?.workgroup, model.sambaConfig?.logonUser].compactMap { $0 }
            .joined(separator: " · "))
        serviceCard(
          "Server FTP", icon: "folder.badge.gearshape",
          available: model.advancedCapabilities.contains(.ftp),
          enabled: model.ftpConfig?.enabled,
          details: model.ftpConfig?.controlPort.map { "porta \($0)" } ?? "")
        serviceCard(
          "UPnP IGD", icon: "arrow.triangle.2.circlepath",
          available: model.advancedCapabilities.contains(.upnpIGD),
          enabled: model.upnpIGDConfig?.enabled,
          details: model.upnpIGDConfig?.version.map { "versione \($0)" } ?? "")
        serviceCard(
          "UPnP AV", icon: "play.rectangle.on.rectangle",
          available: model.advancedCapabilities.contains(.upnpAV),
          enabled: model.upnpAVConfig?.enabled, details: "")
        serviceCard(
          "Accesso remoto", icon: "globe.badge.chevron.backward",
          available: model.advancedCapabilities.contains(.remoteAccess),
          enabled: model.connectionConfiguration?.apiRemoteAccess,
          details: model.connectionConfiguration?.remoteAccessPort.map { "porta \($0)" } ?? "")
        Text("Le credenziali write-only non vengono lette né mostrate da IliadBar.")
          .font(.caption).foregroundStyle(.secondary)
      }
      .padding(20)
    }
  }

  private var family: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Profili e pianificazioni").font(.headline)
        Spacer()
        Button {
          showAddParentalRule = true
        } label: {
          Label("Nuovo profilo", systemImage: "plus")
        }
        .disabled(!model.parentalControlAllowed)
      }
      .padding()
      if !model.parentalControlAllowed {
        Label(
          "Modalità consultazione: abilita il permesso Controllo parentale sulla iliadbox per modificare profili e orari.",
          systemImage: "lock"
        )
        .font(.callout).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
      }
      if model.advancedCapabilities.contains(.parental) {
        List(model.parentalRules) { rule in
          HStack {
            Image(
              systemName: rule.filterState == "denied" ? "hand.raised.fill" : "checkmark.shield"
            )
            .foregroundStyle(rule.filterState == "denied" ? .red : .green)
            VStack(alignment: .leading, spacing: 3) {
              Text(
                rule.description?.isEmpty == false
                  ? rule.description!
                  : (rule.hosts?.joined(separator: ", ") ?? "Profilo \(rule.id)"))
              Text(
                "\(parentalState(rule.filterState)) · \(rule.schedulingMode ?? "pianificazione")"
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(rule.macs.count) dispositivi").font(.caption).foregroundStyle(.secondary)
            Button("Pianificazione") { selectedParentalRule = rule }
              .buttonStyle(.borderless)
            Button(role: .destructive) {
              pendingParentalDeletion = rule
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!model.parentalControlAllowed)
            .accessibilityLabel("Elimina profilo")
          }
          .padding(.vertical, 3)
        }
        .overlay {
          if model.parentalRules.isEmpty {
            ContentUnavailableView("Nessuna regola", systemImage: "figure.2.and.child.holdinghands")
          }
        }
      } else {
        unavailablePage("Controllo parentale", icon: "figure.2.and.child.holdinghands")
      }
    }
  }

  private var communications: some View {
    HSplitView {
      VStack(alignment: .leading, spacing: 0) {
        Text("Chiamate recenti").font(.headline).padding()
        if model.advancedCapabilities.contains(.calls) {
          List(model.callLog) { call in
            HStack {
              Image(systemName: callIcon(call.type)).foregroundStyle(
                call.type == "missed" ? .red : .secondary)
              VStack(alignment: .leading) {
                Text(call.name?.isEmpty == false ? call.name! : call.number)
                Text(Date(timeIntervalSince1970: TimeInterval(call.timestamp)), style: .date)
                  .font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              if let duration = call.duration {
                Text(Format.uptime(Int64(duration))).font(.caption).monospacedDigit()
              }
            }
          }
        } else {
          unavailablePage("Registro chiamate", icon: "phone")
        }
      }
      VStack(alignment: .leading, spacing: 0) {
        Text("Contatti").font(.headline).padding()
        if model.advancedCapabilities.contains(.contacts) {
          List(model.contacts) { contact in
            Label(contactName(contact), systemImage: "person.crop.circle")
          }
        } else {
          unavailablePage("Contatti", icon: "person.crop.circle")
        }
      }
    }
  }

  private var media: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        GroupBox("VPN client") {
          if model.advancedCapabilities.contains(.vpn), let vpn = model.vpnClientStatus {
            VStack(alignment: .leading, spacing: 7) {
              LabeledContent(
                "Stato", value: vpn.state ?? (vpn.enabled == true ? "attiva" : "disattiva"))
              LabeledContent("Profilo", value: vpn.activeDescription ?? vpn.activeVPN ?? "—")
              LabeledContent("Tipo", value: vpn.type?.uppercased() ?? "—")
              if vpn.lastError != nil, vpn.lastError != "none" {
                LabeledContent("Ultimo errore", value: vpn.lastError!)
              }
            }
          } else {
            unavailable("VPN client")
          }
        }
        GroupBox("VPN server") {
          if model.advancedCapabilities.contains(.vpnServer) {
            VStack(spacing: 0) {
              ForEach(model.vpnServers) { server in
                HStack {
                  Circle().fill(server.state == "started" ? Color.green : Color.secondary).frame(
                    width: 7, height: 7)
                  VStack(alignment: .leading) {
                    Text(server.name)
                    Text(server.type.uppercased()).font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(
                    "\(server.authenticatedConnectionCount ?? server.connectionCount ?? 0) connessioni"
                  )
                  .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 7)
                if server.id != model.vpnServers.last?.id { Divider() }
              }
            }
          } else {
            unavailable("VPN server")
          }
        }
        GroupBox("Registrazioni programmate") {
          if model.advancedCapabilities.contains(.pvr) {
            VStack(spacing: 0) {
              ForEach(model.pvrRecords) { record in
                HStack {
                  VStack(alignment: .leading) {
                    Text(record.name)
                    Text(
                      [record.channelName, record.state].compactMap { $0 }.joined(separator: " · ")
                    )
                    .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(Date(timeIntervalSince1970: TimeInterval(record.start)), style: .date)
                    .font(.caption)
                  if record.conflict == true {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                  }
                }
                .padding(.vertical, 7)
                if record.id != model.pvrRecords.last?.id { Divider() }
              }
              if model.pvrRecords.isEmpty {
                Text("Nessuna registrazione programmata").foregroundStyle(.secondary).padding()
              }
            }
          } else {
            unavailable("PVR")
          }
        }
      }
      .padding(20)
    }
  }

  @ViewBuilder private var permissionNotice: some View {
    if !model.networkSettingsAllowed {
      Label(
        "Modalità consultazione: abilita il permesso Impostazioni sulla iliadbox per modificare le regole.",
        systemImage: "lock"
      )
      .font(.callout).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
    }
  }
  private func unavailable(_ name: String) -> some View {
    Label("\(name) non disponibile su questa box o non autorizzato", systemImage: "slash.circle")
      .foregroundStyle(.secondary).padding(.vertical, 8)
  }
  private func unavailablePage(_ name: String, icon: String) -> some View {
    ContentUnavailableView(
      "\(name) non disponibile", systemImage: icon,
      description: Text("Il modulo non è esposto o non è autorizzato su questa iliadbox."))
  }
  private func serviceCard(
    _ title: String, icon: String, available: Bool, enabled: Bool?, details: String
  ) -> some View {
    GroupBox {
      HStack {
        Image(systemName: icon).font(.title2).frame(width: 34)
        VStack(alignment: .leading) {
          Text(title).fontWeight(.medium)
          Text(
            available
              ? (details.isEmpty ? "Configurazione disponibile" : details) : "Non disponibile"
          )
          .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if available {
          Text(enabled == true ? "Attivo" : "Disattivo").foregroundStyle(
            enabled == true ? .green : .secondary)
        }
      }
    }
  }
  private func serviceName(_ id: String) -> String {
    [
      "http": "Accesso remoto HTTP", "https": "Accesso remoto HTTPS", "ftp": "FTP",
      "ftp_pasv": "FTP passivo", "bittorrent-main": "BitTorrent",
      "bittorrent-dht": "BitTorrent DHT",
    ][id] ?? id
  }
  private func parentalState(_ state: String?) -> String {
    switch state {
    case "denied": "bloccato"
    case "webonly": "solo web"
    default: "consentito"
    }
  }
  private func callIcon(_ type: String) -> String {
    switch type {
    case "missed": "phone.down.fill"
    case "outgoing": "phone.arrow.up.right"
    default: "phone.arrow.down.left"
    }
  }
  private func contactName(_ contact: ContactEntry) -> String {
    contact.displayName
      ?? [contact.firstName, contact.lastName].compactMap { $0 }.joined(separator: " ")
  }
}

private struct ParentalPlanningSheet: View {
  @ObservedObject var model: AppModel
  let rule: ParentalRule
  @Environment(\.dismiss) private var dismiss
  private let days = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]
  @State private var draftMapping: [String] = []
  @State private var saving = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading) {
          Text("Pianificazione").font(.title2.bold())
          Text(
            rule.description?.isEmpty == false
              ? rule.description! : (rule.hosts?.joined(separator: ", ") ?? "Profilo \(rule.id)")
          )
          .foregroundStyle(.secondary)
        }
        Spacer()
        if model.parentalControlAllowed {
          Button("Salva") {
            saving = true
            Task {
              await model.saveParentalPlanning(for: rule, mapping: draftMapping)
              saving = false
            }
          }
          .disabled(saving || draftMapping.isEmpty)
          .keyboardShortcut(.defaultAction)
        }
        Button("Chiudi") { dismiss() }
      }
      if let planning = model.selectedParentalPlanning {
        VStack(spacing: 8) {
          ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            HStack(spacing: 6) {
              Text(day).font(.caption).frame(width: 28, alignment: .leading)
              HStack(spacing: 1) {
                ForEach(0..<planning.resolution, id: \.self) { slot in
                  Rectangle()
                    .fill(planningColor(state: state(planning, day: dayIndex, slot: slot)))
                    .frame(height: 18)
                    .contentShape(Rectangle())
                    .onTapGesture {
                      guard model.parentalControlAllowed else { return }
                      cycleState(planning, day: dayIndex, slot: slot)
                    }
                    .accessibilityLabel(
                      "\(day), fascia \(slot + 1): \(state(planning, day: dayIndex, slot: slot))")
                }
              }
              .clipShape(RoundedRectangle(cornerRadius: 4))
            }
          }
        }
        HStack(spacing: 14) {
          legend("Consentito", .green)
          legend("Solo web", .orange)
          legend("Bloccato", .red)
        }
        if model.parentalControlAllowed {
          Text("Seleziona le fasce per alternare consentito, solo web e bloccato.")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          Text(
            "La pianificazione è mostrata in sola lettura. Le modifiche richiedono il permesso Controllo parentale."
          )
          .font(.caption).foregroundStyle(.secondary)
        }
      } else {
        ProgressView("Carico pianificazione…").frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(20).frame(width: 720, height: 390)
    .task {
      await model.loadParentalPlanning(for: rule)
      draftMapping = model.selectedParentalPlanning?.mapping ?? []
    }
  }

  private func state(_ planning: ParentalPlanning, day: Int, slot: Int) -> String {
    let index = day * planning.resolution + slot
    if draftMapping.indices.contains(index) { return draftMapping[index] }
    return planning.mapping.indices.contains(index) ? planning.mapping[index] : "allowed"
  }
  private func cycleState(_ planning: ParentalPlanning, day: Int, slot: Int) {
    let index = day * planning.resolution + slot
    guard draftMapping.indices.contains(index) else { return }
    draftMapping[index] =
      switch draftMapping[index] {
      case ParentalAccessMode.allowed.rawValue: ParentalAccessMode.webonly.rawValue
      case ParentalAccessMode.webonly.rawValue: ParentalAccessMode.denied.rawValue
      default: ParentalAccessMode.allowed.rawValue
      }
  }
  private func planningColor(state: String) -> Color {
    switch state {
    case "denied": .red
    case "webonly": .orange
    default: .green
    }
  }
  private func legend(_ text: String, _ color: Color) -> some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(text).font(.caption)
    }
  }
}

private struct AddParentalRuleSheet: View {
  @ObservedObject var model: AppModel
  @Binding var isPresented: Bool
  @State private var description = ""
  @State private var macText = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Nuovo profilo parentale").font(.title2.bold())
      TextField("Descrizione", text: $description)
      VStack(alignment: .leading, spacing: 5) {
        Text("Indirizzi MAC").font(.callout.weight(.medium))
        TextEditor(text: $macText)
          .font(.body.monospaced())
          .frame(height: 90)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        Text("Inserisci uno o più indirizzi, separati da virgole o righe.")
          .font(.caption).foregroundStyle(.secondary)
      }
      if !macText.isEmpty && !macsAreValid {
        Label("Controlla il formato degli indirizzi MAC.", systemImage: "exclamationmark.triangle")
          .font(.caption).foregroundStyle(.red)
      }
      HStack {
        Button("Annulla", role: .cancel) { isPresented = false }
        Spacer()
        Button("Crea") {
          let macs = normalizedMacs
          isPresented = false
          Task { await model.addParentalRule(description: description, macs: macs) }
        }
        .disabled(!macsAreValid)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20).frame(width: 460)
  }

  private var normalizedMacs: [String] {
    macText
      .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
      .filter { !$0.isEmpty }
  }
  private var macsAreValid: Bool {
    !normalizedMacs.isEmpty
      && normalizedMacs.allSatisfy {
        $0.range(of: #"^([0-9A-F]{2}:){5}[0-9A-F]{2}$"#, options: .regularExpression) != nil
      }
  }
}

private struct AddForwardingRuleSheet: View {
  @ObservedObject var model: AppModel
  @Binding var isPresented: Bool
  @State private var protocolName = "tcp"
  @State private var publicPort = ""
  @State private var lanIP = ""
  @State private var privatePort = ""
  @State private var comment = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Nuova regola").font(.title2.bold())
      Picker("Protocollo", selection: $protocolName) {
        Text("TCP").tag("tcp")
        Text("UDP").tag("udp")
      }.pickerStyle(.segmented)
      TextField("Porta pubblica", text: $publicPort)
      TextField("IP del dispositivo", text: $lanIP)
      TextField("Porta privata", text: $privatePort)
      TextField("Descrizione", text: $comment)
      if let range = model.connection?.assignedPortRange {
        Text(
          "La porta pubblica assegnata deve essere tra \(range.lowerBound) e \(range.upperBound)."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      HStack {
        Spacer()
        Button("Annulla") { isPresented = false }
        Button("Crea") {
          guard let wan = Int(publicPort), let lan = Int(privatePort) else { return }
          isPresented = false
          Task {
            await model.addPortForwarding(
              protocolName: protocolName, publicPort: wan, lanIP: lanIP, privatePort: lan,
              comment: comment)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          Int(publicPort) == nil || Int(privatePort) == nil
            || !IliadboxInputValidator.isIPv4Address(lanIP))
      }
    }
    .padding(20).frame(width: 400)
  }
}
