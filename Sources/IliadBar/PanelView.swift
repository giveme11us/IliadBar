import IliadBarDesign
import IliadboxKit
import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
  case overview, download, file, box
  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .overview: "Stato"
    case .download: "Download"
    case .file: "File"
    case .box: "Box"
    }
  }

  var symbol: String {
    switch self {
    case .overview: "waveform.path.ecg"
    case .download: "arrow.down.circle.fill"
    case .file: "externaldrive.fill"
    case .box: "wifi.router.fill"
    }
  }
}

/// Pannello principale: sezioni divise da Divider, titoli .headline,
/// meta .footnote secondary, righe-azione con icona SF in colonna fissa,
/// barre capsule sottili.
struct PanelView: View {
  @ObservedObject var model: AppModel
  @State private var tab: PanelTab = .overview
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      switcher
      Divider()
      if let status = model.statusLine {
        statusBanner(status)
      }
      if model.paired {
        Group {
          switch tab {
          case .overview: overview
          case .download: downloadTab
          case .file: FilesView(model: model)
          case .box: BoxView(model: model)
          }
        }
        .padding(14)
      } else {
        pairingSection
          .padding(14)
      }
      Divider()
      footer
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
    .frame(width: 380)
    .task { await model.refresh() }
  }

  // MARK: Switcher

  private var switcher: some View {
    HStack(spacing: 4) {
      ForEach(PanelTab.allCases) { candidate in
        Button {
          withAnimation(.easeOut(duration: 0.14)) { tab = candidate }
        } label: {
          VStack(spacing: 5) {
            Image(systemName: candidate.symbol)
              .font(.system(size: 17, weight: .medium))
              .symbolRenderingMode(.hierarchical)
            Text(candidate.title)
              .font(.system(size: 11, weight: tab == candidate ? .semibold : .regular))
              .lineLimit(1)
            switcherMeter(for: candidate)
          }
          .foregroundStyle(tab == candidate ? Color.white : Color.primary.opacity(0.7))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .fill(tab == candidate ? IliadPalette.red : Color.clear)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.title)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }

  private func switcherMeter(for candidate: PanelTab) -> some View {
    let value: Double =
      switch candidate {
      case .overview:
        model.availability.isOnline ? 1 : 0.08
      case .download:
        model.activeTasks.isEmpty
          ? 0.08 : model.activeTasks.map(\.progress).reduce(0, +) / Double(model.activeTasks.count)
      case .file:
        storageFillRatio
      case .box:
        model.connection?.isUp == true ? 1 : 0.08
      }
    return GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(tab == candidate ? Color.white.opacity(0.25) : Color.primary.opacity(0.12))
        Capsule()
          .fill(tab == candidate ? Color.white : meterColor(for: candidate))
          .frame(width: max(3, geometry.size.width * value))
      }
    }
    .frame(height: 3)
  }

  /// Riempimento reale dello storage (usato/totale su tutte le partizioni);
  /// minimo visivo quando i dati non ci sono ancora.
  private var storageFillRatio: Double {
    let partitions = model.storageDisks.flatMap { $0.partitions ?? [] }
    let total = partitions.compactMap(\.totalBytes).reduce(0, +)
    guard total > 0 else { return 0.08 }
    let free = partitions.compactMap(\.freeBytes).reduce(0, +)
    return max(0.08, Double(total - free) / Double(total))
  }

  private func meterColor(for candidate: PanelTab) -> Color {
    switch candidate {
    case .overview, .box: statusColor
    case .download: IliadPalette.blue
    case .file: IliadPalette.violet
    }
  }

  private func statusBanner(_ status: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "info.circle.fill")
      Text(status).lineLimit(2)
      Spacer(minLength: 0)
    }
    .font(.caption)
    .foregroundStyle(IliadPalette.amber)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(IliadPalette.amber.opacity(0.09))
  }

  // MARK: Overview

  private var overview: some View {
    VStack(alignment: .leading, spacing: 13) {
      identityHeader
      if let connection = model.connection {
        trafficSection(connection)
      } else {
        HStack {
          ProgressView().controlSize(.small)
          Text("Leggo lo stato della linea…")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 18)
      }
      Divider()
      activityPreview
      Divider()
      quickActions
    }
    .task {
      while !Task.isCancelled {
        await model.refreshBoxStats()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
      }
    }
  }

  private var identityHeader: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(IliadPalette.red)
        Image(systemName: "wifi.router.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: 34, height: 34)

      VStack(alignment: .leading, spacing: 1) {
        Text(activeBoxName)
          .font(.system(size: 15, weight: .semibold))
        Text(model.system?.modelName ?? "iliadbox")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 5) {
        Circle().fill(statusColor).frame(width: 7, height: 7)
        Text(model.availability.label)
          .font(.caption.weight(.medium))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Capsule().fill(statusColor.opacity(0.12)))
    }
  }

  private func trafficSection(_ connection: ConnectionStatus) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("TRAFFICO IN TEMPO REALE")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if let media = connection.media {
          Text(media.uppercased())
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(IliadPalette.red)
        }
      }
      HStack(spacing: 18) {
        TrafficMetric(
          label: "Download",
          symbol: "arrow.down",
          value: connection.rateDown ?? 0,
          bandwidth: connection.bandwidthDown,
          tint: IliadPalette.blue
        )
        TrafficMetric(
          label: "Upload",
          symbol: "arrow.up",
          value: connection.rateUp ?? 0,
          bandwidth: connection.bandwidthUp,
          tint: IliadPalette.red
        )
      }
      if let system = model.system {
        HStack(spacing: 12) {
          if let uptime = system.uptimeVal {
            SystemDatum(symbol: "clock", value: Format.uptime(uptime))
          }
          if let temperature = system.maxTemperature {
            SystemDatum(symbol: "thermometer.medium", value: "\(temperature) °C")
          }
          if let firmware = system.firmwareVersion {
            SystemDatum(symbol: "shippingbox", value: firmware)
          }
        }
      }
    }
  }

  private var activityPreview: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("DOWNLOAD")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        if !model.activeTasks.isEmpty {
          Text("\(model.activeTasks.count) attivi")
            .font(.caption2)
            .foregroundStyle(IliadPalette.blue)
        }
        Spacer()
        Button("Mostra tutti") { tab = .download }
          .buttonStyle(.plain)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if model.tasks.isEmpty {
        Text("Nessun download sulla box")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 8)
      } else {
        ForEach(model.tasks.prefix(3)) { task in
          TaskRow(task: task, model: model)
        }
      }
    }
  }

  private var quickActions: some View {
    VStack(spacing: 1) {
      ActionRow(icon: "doc.on.clipboard", title: "Aggiungi magnet dagli appunti") {
        Task { await model.addFromPasteboard() }
      }
      ActionRow(icon: "house", title: "Apri IliadBar") {
        open(.home)
      }
      ActionRow(icon: "network", title: "Apri Rete") {
        open(.devices)
      }
      ActionRow(icon: "server.rack", title: "Apri Servizi") {
        open(.nat)
      }
    }
  }

  /// Porta la finestra unica sulla sezione richiesta e la mostra.
  private func open(_ section: MainSection) {
    model.mainWindowSection = section
    openWindow(id: IliadBarWindow.main)
  }

  private var activeBoxName: String {
    model.profiles.first { $0.id == model.activeProfileID }?.name ?? "IliadBar"
  }

  // MARK: Download

  @ViewBuilder
  private var downloadTab: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text("Download")
            .font(.system(size: 16, weight: .semibold))
          Text(downloadSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          Task { await model.refresh() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Aggiorna")
        .accessibilityLabel("Aggiorna")
      }

      if model.tasks.isEmpty {
        VStack(spacing: 7) {
          Image(systemName: "arrow.down.circle")
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.tertiary)
          Text("Nessun download sulla box")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(model.tasks.prefix(8)) { task in
              TaskRow(task: task, model: model)
            }
          }
        }
        .frame(maxHeight: 280)
        if model.tasks.count > 8 {
          Text("…e altri \(model.tasks.count - 8)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }

      Divider()
      ActionRow(icon: "doc.on.clipboard", title: "Aggiungi magnet dagli appunti") {
        Task { await model.addFromPasteboard() }
      }
      ActionRow(icon: "link", title: "Usa IliadBar per i link magnet") {
        model.registerAsMagnetHandler()
      }
      ActionRow(icon: "arrow.down.circle", title: "Apri Download") {
        open(.download)
      }
    }
  }

  private var downloadSummary: String {
    if let stats = model.downloadStats, let rate = stats.rxRate, rate > 0 {
      return "\(model.activeTasks.count) attivi · \(Format.bytes(rate))/s"
    }
    return model.tasks.isEmpty ? "Nessuna attività" : "\(model.tasks.count) elementi"
  }

  // MARK: Pairing

  private var pairingSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        ZStack {
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(IliadPalette.red.opacity(0.12))
          Image(systemName: "wifi.router")
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(IliadPalette.red)
        }
        .frame(width: 42, height: 42)
        VStack(alignment: .leading, spacing: 2) {
          Text("Collega la tua iliadbox")
            .font(.system(size: 16, weight: .semibold))
          Text("I download, i file e la rete restano sul tuo Mac.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      if !model.profiles.isEmpty {
        Button {
          Task { await model.activateSavedCredential() }
        } label: {
          Label(
            model.credentialActivationInProgress
              ? "Attendo il Portachiavi…" : "Sblocca credenziale salvata",
            systemImage: "key.fill"
          )
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(IliadPalette.red)
        .disabled(model.credentialActivationInProgress)
      }
      Button {
        Task { await model.pair() }
      } label: {
        Label(
          model.pairingInProgress ? "In attesa di conferma sulla box…" : "Nuova associazione",
          systemImage: "link.badge.plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(model.pairingInProgress)
    }
  }

  // MARK: Footer

  private var footer: some View {
    HStack(spacing: 12) {
      Button {
        Task { await model.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.plain)
      .help("Aggiorna")
      SettingsLink {
        Image(systemName: "gearshape")
      }
      .buttonStyle(.plain)
      .help("Impostazioni")
      Button {
        (NSApplication.shared.delegate as? AppDelegate)?.updaterController.checkForUpdates(nil)
      } label: {
        Image(systemName: "arrow.triangle.2.circlepath")
      }
      .buttonStyle(.plain)
      .help("Controlla aggiornamenti")
      Spacer()
      Text("IliadBar \(IliadboxClient.appVersion)")
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.tertiary)
      Button("Esci") { NSApplication.shared.terminate(nil) }
        .buttonStyle(.plain)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .keyboardShortcut("q")
    }
    .foregroundStyle(.secondary)
  }

  private var statusColor: Color {
    guard model.paired else { return IliadTint.connecting }
    return switch model.availability {
    case .online: IliadTint.online
    case .connecting: IliadTint.connecting
    case .stale: IliadTint.stale
    case .offline, .unconfigured: IliadTint.offline
    }
  }
}

private struct TrafficMetric: View {
  let label: LocalizedStringKey
  let symbol: String
  let value: Int64
  let bandwidth: Int64?
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 4) {
        Image(systemName: symbol)
          .font(.caption.weight(.bold))
          .foregroundStyle(tint)
        Text(label)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Text("\(Format.bytes(value))/s")
        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      ProgressBarView(
        percent: ConnectionStatus.usagePercent(rate: value, bandwidth: bandwidth),
        tint: tint
      )
      if let bandwidth, bandwidth > 0 {
        Text("su \(Format.bits(bandwidth))")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct SystemDatum: View {
  let symbol: String
  let value: String

  var body: some View {
    Label(value, systemImage: symbol)
      .font(.caption2.monospacedDigit())
      .foregroundStyle(.secondary)
      .lineLimit(1)
  }
}

// MARK: - Riga azione (icona in colonna fissa da 18pt)

struct ActionRow: View {
  let icon: String
  /// LocalizedStringKey e non String: `Text(String)` non localizza.
  let title: LocalizedStringKey
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .imageScale(.medium)
          .frame(width: 18)
        Text(title)
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
      .padding(.vertical, 3)
      .padding(.horizontal, 5)
      .background(
        RoundedRectangle(cornerRadius: 5)
          .fill(hovering ? Color.primary.opacity(0.08) : .clear)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

// MARK: - Riga download

private struct TaskRow: View {
  let task: DownloadTask
  let model: AppModel
  @State private var hovering = false

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Text(task.name ?? "…")
          .font(.callout)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: 4)
        if hovering, canControl {
          Button {
            Task { await model.togglePause(task) }
          } label: {
            Image(systemName: task.status == "stopped" ? "play.fill" : "pause.fill")
              .imageScale(.small)
          }
          .buttonStyle(.plain)
          .help(task.status == "stopped" ? "Riprendi" : "Pausa")
          .accessibilityLabel(task.status == "stopped" ? "Riprendi" : "Pausa")
          Button {
            Task { await model.remove(task) }
          } label: {
            Image(systemName: "xmark")
              .imageScale(.small)
          }
          .buttonStyle(.plain)
          .help("Rimuovi il task (i file restano sulla box)")
          .accessibilityLabel("Rimuovi il task (i file restano sulla box)")
        } else {
          Text(percentText)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
      }
      ProgressBarView(percent: task.progress * 100, tint: IliadTint.downloadStatus(task.status))
      Text(metaText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .onHover { hovering = $0 }
  }

  private var canControl: Bool {
    !["done", "error"].contains(task.status ?? "")
  }

  private var percentText: String {
    task.status == "done" ? "100%" : "\(Int(task.progress * 100))%"
  }

  private var metaText: String {
    var parts = [DownloadPresentation.statusLabel(task)]
    if task.status == "downloading" {
      if let rate = task.rxRate, rate > 0 {
        parts.append("\(Format.bytes(rate))/s")
      }
      if let eta = task.eta, eta > 0 {
        parts.append("~\(Format.duration(eta))")
      }
    }
    if let size = task.size, size > 0 {
      parts.append(Format.bytes(size))
    }
    return parts.joined(separator: " · ")
  }
}

// MARK: - Barra di progresso (Canvas singolo: niente modificatori di compositing
// SwiftUI, che su macOS 26 possono rompere il rendering delle status item)

struct ProgressBarView: View {
  let percent: Double
  let tint: Color

  var body: some View {
    Canvas { context, size in
      let corner = CGSize(width: size.height / 2, height: size.height / 2)
      let rect = CGRect(origin: .zero, size: size)
      var track = Path()
      track.addRoundedRect(in: rect, cornerSize: corner)
      context.fill(track, with: .color(.primary.opacity(0.12)))

      let width = size.width * min(100, max(0, percent)) / 100
      if width > 0 {
        var fill = Path()
        fill.addRoundedRect(
          in: CGRect(x: 0, y: 0, width: width, height: size.height),
          cornerSize: corner
        )
        context.fill(fill, with: .color(tint))
      }
    }
    .frame(height: 5)
  }
}

// MARK: - Formattazione

enum Format {
  static func bytes(_ value: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: value)
  }

  /// Banda in bit/s → "5 Gbit/s", "700 Mbit/s".
  static func bits(_ value: Int64) -> String {
    let mbit = Double(value) / 1_000_000
    if mbit >= 1000 {
      let gbit = mbit / 1000
      return gbit == gbit.rounded() ? "\(Int(gbit)) Gbit/s" : String(format: "%.1f Gbit/s", gbit)
    }
    return "\(Int(mbit)) Mbit/s"
  }

  static func duration(_ seconds: Int64) -> String {
    if seconds < 60 { return "\(seconds)s" }
    if seconds < 3600 { return "\(seconds / 60) min" }
    return String(format: "%dh %02dm", seconds / 3600, (seconds % 3600) / 60)
  }

  /// Uptime compatto: "14g 6h", "3h 12m".
  static func uptime(_ seconds: Int64) -> String {
    let days = seconds / 86400
    let hours = (seconds % 86400) / 3600
    let minutes = (seconds % 3600) / 60
    if days > 0 { return "\(days)g \(hours)h" }
    if hours > 0 { return "\(hours)h \(minutes)m" }
    return "\(minutes)m"
  }
}
