import AppKit
import CoreImage
import IliadboxKit
import SwiftUI

enum NetworkSection: String, CaseIterable, Identifiable {
  case devices, wifi, dhcp
  var id: String { rawValue }
  var title: LocalizedStringKey {
    switch self {
    case .devices: "Dispositivi"
    case .wifi: "Wi‑Fi"
    case .dhcp: "DHCP"
    }
  }
}

/// Sezione Rete della finestra unica: il sidebar vive in MainWindowView,
/// qui resta il solo dettaglio.
struct NetworkView: View {
  @ObservedObject var model: AppModel
  let section: NetworkSection
  @State private var search = ""
  @State private var renameHost: LanHost?
  @State private var proposedName = ""
  @State private var pendingWifiValue: Bool?
  @State private var pendingLeaseDeletion: DhcpStaticLease?
  @State private var showAddLease = false

  var body: some View {
    Group {
      switch section {
      case .devices: devices
      case .wifi: wifi
      case .dhcp: dhcp
      }
    }
    .navigationTitle(section.title)
    .toolbar {
      ToolbarItem {
        Label(
          model.liveEventsConnected ? "Live" : "Polling",
          systemImage: model.liveEventsConnected
            ? "bolt.horizontal.circle.fill" : "clock.arrow.circlepath"
        )
        .font(.caption).foregroundStyle(.secondary)
        .help(
          model.liveEventsConnected
            ? "Aggiornamenti rete in tempo reale"
            : "WebSocket non disponibile: aggiornamento su richiesta")
      }
      ToolbarItem {
        Button {
          Task { await model.refreshNetwork() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .help("Aggiorna la rete")
        .accessibilityLabel("Aggiorna la rete")
      }
    }
    .task { await model.refreshNetwork() }
    .alert(
      "Rinomina dispositivo",
      isPresented: Binding(
        get: { renameHost != nil },
        set: { if !$0 { renameHost = nil } }
      )
    ) {
      TextField("Nome", text: $proposedName)
      Button("Annulla", role: .cancel) { renameHost = nil }
      Button("Rinomina") {
        guard let host = renameHost else { return }
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        renameHost = nil
        if !name.isEmpty { Task { await model.renameLanHost(host, to: name) } }
      }
    }
    .confirmationDialog(
      pendingWifiValue == false ? "Disattivare il Wi‑Fi?" : "Attivare il Wi‑Fi?",
      isPresented: Binding(
        get: { pendingWifiValue != nil },
        set: { if !$0 { pendingWifiValue = nil } }
      )
    ) {
      Button(
        pendingWifiValue == false ? "Disattiva Wi‑Fi" : "Attiva Wi‑Fi",
        role: pendingWifiValue == false ? .destructive : nil
      ) {
        guard let value = pendingWifiValue else { return }
        pendingWifiValue = nil
        Task { await model.setWifiEnabled(value) }
      }
      Button("Annulla", role: .cancel) { pendingWifiValue = nil }
    } message: {
      Text(
        "La modifica viene applicata immediatamente alla iliadbox e può interrompere i dispositivi collegati."
      )
    }
    .sheet(isPresented: $showAddLease) {
      AddLeaseSheet(model: model, isPresented: $showAddLease)
    }
    .confirmationDialog(
      "Rimuovere la prenotazione DHCP?",
      isPresented: Binding(
        get: { pendingLeaseDeletion != nil },
        set: { if !$0 { pendingLeaseDeletion = nil } }
      )
    ) {
      Button("Rimuovi prenotazione", role: .destructive) {
        guard let lease = pendingLeaseDeletion else { return }
        pendingLeaseDeletion = nil
        Task { await model.deleteDhcpLease(lease) }
      }
      Button("Annulla", role: .cancel) { pendingLeaseDeletion = nil }
    } message: {
      Text("Il dispositivo tornerà a ricevere un indirizzo dinamico dal server DHCP.")
    }
  }

  private var filteredHosts: [LanHost] {
    guard !search.isEmpty else { return model.lanHosts }
    return model.lanHosts.filter {
      [$0.primaryName, $0.vendorName, $0.ipv4Address, $0.macAddress]
        .compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(search) }
    }
  }

  private var devices: some View {
    VStack(spacing: 0) {
      if model.networkLoading && model.lanHosts.isEmpty {
        ProgressView().controlSize(.small).padding()
      }
      List(filteredHosts) { host in
        HStack(spacing: 12) {
          Image(systemName: deviceIcon(host.hostType))
            .font(.title3)
            .frame(width: 28)
            .foregroundStyle(host.reachable == true ? .primary : .tertiary)
          VStack(alignment: .leading, spacing: 3) {
            HStack {
              Text(host.primaryName).fontWeight(.medium)
              if host.reachable == true {
                Text("online").font(.caption2).foregroundStyle(.green)
              }
            }
            Text(
              verbatim: [
                host.vendorName, host.ipv4Address, host.macAddress, model.interfaceName(for: host),
              ].compactMap { $0 }.joined(separator: " · ")
            )
            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if let timestamp = host.lastActivity, timestamp > 0 {
              Text(
                "Ultima attività \(Date(timeIntervalSince1970: TimeInterval(timestamp)), style: .relative)"
              )
              .font(.caption2).foregroundStyle(.tertiary)
            }
          }
          Spacer()
          if let access = host.accessPoint {
            VStack(alignment: .trailing, spacing: 3) {
              Text(connectionLabel(access)).font(.caption)
              if let signal = access.wifiInformation?.signal {
                Text("\(signal) dBm").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
              }
            }
          }
          Button {
            proposedName = host.primaryName
            renameHost = host
          } label: {
            Image(systemName: "pencil")
          }
          .buttonStyle(.borderless).help("Rinomina")
          .disabled(!model.networkSettingsAllowed)
          .accessibilityLabel("Rinomina dispositivo")
        }
        .padding(.vertical, 4)
      }
      .searchable(text: $search, prompt: "Nome, IP o MAC")
    }
  }

  private var wifi: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        GroupBox {
          HStack {
            Label(
              model.wifiConfig?.enabled == true ? "Wi‑Fi attivo" : "Wi‑Fi disattivo",
              systemImage: "wifi")
            Spacer()
            Toggle(
              "",
              isOn: Binding(
                get: { model.wifiConfig?.enabled == true },
                set: { pendingWifiValue = $0 }
              )
            )
            .labelsHidden()
            .disabled(!model.networkSettingsAllowed || model.wifiConfig == nil)
          }
        } label: {
          Text("Stato")
        }

        if !model.networkSettingsAllowed {
          Label(
            "Consultazione disponibile. Per modificare il Wi‑Fi abilita il permesso Impostazioni sulla iliadbox.",
            systemImage: "lock"
          )
          .font(.callout).foregroundStyle(.secondary)
        }

        ForEach(model.wifiBSSs) { bss in
          GroupBox {
            HStack(alignment: .top, spacing: 18) {
              VStack(alignment: .leading, spacing: 7) {
                LabeledContent("SSID", value: bss.config?.ssid ?? "—")
                LabeledContent(
                  "Sicurezza",
                  value: NetworkPresentation.wifiEncryptionLabel(bss.config?.encryption)
                )
                LabeledContent(
                  "Stato", value: NetworkPresentation.wifiStateLabel(bss.status?.state))
                LabeledContent("Client", value: "\(bss.status?.stationCount ?? 0)")
                if let enabled = bss.config?.enabled {
                  Toggle(
                    "Rete attiva",
                    isOn: Binding(
                      get: { enabled },
                      set: { value in Task { await model.setWifiBSSEnabled(bss, enabled: value) } }
                    )
                  )
                  .disabled(!model.networkSettingsAllowed)
                }
                if let wps = bss.config?.wpsEnabled {
                  Toggle(
                    "WPS",
                    isOn: Binding(
                      get: { wps },
                      set: { value in Task { await model.setWifiBSSWPS(bss, enabled: value) } }
                    )
                  )
                  .disabled(!model.networkSettingsAllowed)
                  .help("Attiva o disattiva l'accoppiamento WPS per questa rete")
                }
              }
              Spacer()
              if let payload = wifiPayload(for: bss), let image = qrImage(payload) {
                VStack(spacing: 6) {
                  Image(nsImage: image).interpolation(.none).resizable().frame(
                    width: 112, height: 112)
                  Text("Scansiona per collegarti").font(.caption2).foregroundStyle(.secondary)
                }
                .accessibilityLabel("Codice QR per la rete \(bss.config?.ssid ?? "Wi-Fi")")
              }
            }
          } label: {
            Text(bss.config?.ssid ?? bss.id).fontWeight(.semibold)
          }
        }

        if !model.wifiAccessPoints.isEmpty {
          GroupBox("Radio") {
            VStack(spacing: 10) {
              ForEach(model.wifiAccessPoints) { ap in
                HStack {
                  Text(ap.name).fontWeight(.medium)
                  Spacer()
                  Text(NetworkPresentation.wifiBandLabel(ap.config?.band))
                  Text(channelLabel(ap)).foregroundStyle(.secondary)
                }
                if ap.id != model.wifiAccessPoints.last?.id { Divider() }
              }
            }
          }
        }
        if !model.wifiStations.isEmpty {
          GroupBox("Dispositivi Wi‑Fi collegati") {
            VStack(spacing: 8) {
              ForEach(model.wifiStations) { station in
                HStack {
                  Image(systemName: "wifi")
                  VStack(alignment: .leading) {
                    Text(station.hostname ?? station.mac ?? station.id)
                    Text(
                      verbatim: [station.mac, station.signal.map { "\($0) dBm" }].compactMap { $0 }
                        .joined(separator: " · ")
                    )
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                  }
                  Spacer()
                  Text(NetworkPresentation.wifiStateLabel(station.state))
                    .font(.caption).foregroundStyle(.secondary)
                }
                if station.id != model.wifiStations.last?.id { Divider() }
              }
            }
          }
        }
      }
      .padding(20)
    }
  }

  private var dhcp: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Prenotazioni IP permanenti").font(.headline)
        Spacer()
        Button {
          showAddLease = true
        } label: {
          Label("Aggiungi", systemImage: "plus")
        }
        .disabled(!model.networkSettingsAllowed)
      }
      .padding()
      if let config = model.dhcpConfig {
        HStack(spacing: 16) {
          Label(
            config.enabled ? "Server attivo" : "Server disattivo",
            systemImage: config.enabled ? "checkmark.circle.fill" : "pause.circle")
          if let start = config.rangeStart, let end = config.rangeEnd {
            Text("Pool \(start) – \(end)").monospacedDigit()
          }
          if let gateway = config.gateway { Text("Gateway \(gateway)").monospacedDigit() }
          Spacer()
        }
        .font(.caption).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
      }
      if !model.networkSettingsAllowed {
        Label(
          "Il permesso Impostazioni è necessario per aggiungere o rimuovere prenotazioni.",
          systemImage: "lock"
        )
        .font(.callout).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 8)
      }
      List(model.dhcpLeases) { lease in
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text(lease.hostname ?? lease.comment ?? "Dispositivo")
            Text("\(lease.ip) · \(lease.mac)").font(.caption).foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
          Spacer()
          Button(role: .destructive) {
            pendingLeaseDeletion = lease
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(.borderless).disabled(!model.networkSettingsAllowed)
          .accessibilityLabel("Rimuovi prenotazione")
        }
        .padding(.vertical, 3)
      }
      .overlay {
        if model.dhcpLeases.isEmpty && !model.networkLoading {
          ContentUnavailableView("Nessuna prenotazione", systemImage: "network")
        }
      }
    }
  }

  private func deviceIcon(_ type: String?) -> String {
    switch type?.lowercased() {
    case "smartphone", "phone": "iphone"
    case "tablet": "ipad"
    case "printer": "printer"
    case "television", "tv": "tv"
    default: "desktopcomputer"
    }
  }
  private func connectionLabel(_ access: LanAccessPoint) -> String {
    if let ssid = access.wifiInformation?.ssid { return ssid }
    return access.connectivityType?.capitalized ?? "LAN"
  }
  private func channelLabel(_ ap: WifiAccessPoint) -> String {
    let channel = ap.status?.primaryChannel ?? ap.config?.primaryChannel
    let width = ap.status?.channelWidth?.intValue ?? ap.config?.channelWidth?.intValue
    return [channel.map { "canale \($0)" }, width.map { "\($0) MHz" }].compactMap { $0 }.joined(
      separator: " · ")
  }
  private func wifiPayload(for bss: WifiBSS) -> String? {
    guard let config = bss.config, config.enabled != false, let ssid = config.ssid, !ssid.isEmpty
    else { return nil }
    let encryption = config.encryption?.lowercased() ?? ""
    let type =
      encryption.contains("wep")
      ? "WEP" : (encryption.contains("open") || encryption == "none" ? "nopass" : "WPA")
    if type != "nopass", config.key?.isEmpty != false { return nil }
    func escape(_ value: String) -> String {
      value.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: ";", with: "\\;")
        .replacingOccurrences(of: ",", with: "\\,")
        .replacingOccurrences(of: ":", with: "\\:")
    }
    return
      "WIFI:T:\(type);S:\(escape(ssid));P:\(escape(config.key ?? ""));H:\(config.hidesSSID == true ? "true" : "false");;"
  }
  private func qrImage(_ text: String) -> NSImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(text.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
      let representation = CIContext().createCGImage(output, from: output.extent)
    else { return nil }
    return NSImage(cgImage: representation, size: NSSize(width: 112, height: 112))
  }
}

/// Scelta di un dispositivo già visto sulla rete: usata da prenotazioni DHCP
/// e regole NAT per non far digitare indirizzi che l'app conosce.
struct LanHostPicker: View {
  let hosts: [LanHost]
  let onSelect: (LanHost) -> Void

  var body: some View {
    Menu {
      if hosts.isEmpty {
        Text("Nessun dispositivo rilevato")
      }
      ForEach(hosts) { host in
        Button {
          onSelect(host)
        } label: {
          Text(verbatim: label(for: host))
        }
      }
    } label: {
      Label("Scegli un dispositivo", systemImage: "desktopcomputer")
    }
    .disabled(hosts.isEmpty)
  }

  private func label(for host: LanHost) -> String {
    [host.primaryName, host.ipv4Address].compactMap { $0 }.joined(separator: " · ")
  }
}

private struct AddLeaseSheet: View {
  @ObservedObject var model: AppModel
  @Binding var isPresented: Bool
  @State private var ip = ""
  @State private var mac = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Nuova prenotazione DHCP").font(.title2.bold())
      // L'app conosce già i dispositivi della LAN: sceglierne uno riempie
      // i campi invece di farli ricopiare a mano.
      LanHostPicker(hosts: model.lanHosts) { host in
        ip = host.ipv4Address ?? ip
        mac = host.macAddress ?? mac
      }
      TextField("Indirizzo IPv4", text: $ip)
      TextField("Indirizzo MAC", text: $mac)
      HStack {
        Spacer()
        Button("Annulla") { isPresented = false }
        Button("Aggiungi") {
          isPresented = false
          Task { await model.addDhcpLease(ip: ip, mac: mac) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          !IliadboxInputValidator.isIPv4Address(ip.trimmingCharacters(in: .whitespaces))
            || !IliadboxInputValidator.isMACAddress(mac.trimmingCharacters(in: .whitespaces)))
      }
    }
    .padding(20).frame(width: 380)
  }
}
