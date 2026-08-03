import SwiftUI
import IliadboxKit

enum PanelTab: String, CaseIterable, Identifiable {
    case download, file, box
    var id: String { rawValue }

    var title: String {
        switch self {
        case .download: "Download"
        case .file: "File"
        case .box: "Box"
        }
    }
}

/// Pannello principale: sezioni divise da Divider, titoli .headline,
/// meta .footnote secondary, righe-azione con icona SF in colonna fissa,
/// barre capsule sottili.
struct PanelView: View {
    @ObservedObject var model: AppModel
    @State private var tab: PanelTab = .download

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let status = model.statusLine {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if model.paired {
                tabBar
                Divider()
                switch tab {
                case .download: downloadTab
                case .file: FilesView(model: model)
                case .box: BoxView(model: model)
                }
            } else {
                Divider()
                pairingSection
            }
            Divider()
            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 320)
        .task { await model.refresh() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("IliadBar").font(.headline)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(model.paired ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(model.paired ? "iliadbox associata" : "non associata")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(PanelTab.allCases) { candidate in
                Button {
                    tab = candidate
                } label: {
                    Text(candidate.title)
                        .font(.footnote.weight(tab == candidate ? .semibold : .regular))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(tab == candidate ? Color.primary.opacity(0.1) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Tab Download

    @ViewBuilder
    private var downloadTab: some View {
        HStack {
            Text("DOWNLOAD")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if !model.activeTasks.isEmpty {
                Text("\(model.activeTasks.count) attivi")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Aggiorna")
        }

        if model.tasks.isEmpty {
            Text("Nessun download sulla box")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(model.tasks.prefix(8)) { task in
                    TaskRow(task: task, model: model)
                }
            }
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
    }

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IliadBar non è ancora associata alla tua iliadbox.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.pair() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .frame(width: 18)
                    Text(model.pairingInProgress ? "In attesa di conferma sulla box…" : "Associa alla iliadbox")
                }
            }
            .buttonStyle(.plain)
            .disabled(model.pairingInProgress)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Toggle("Avvia al login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.footnote)
            Spacer()
            Text("v\(IliadboxClient.appVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Esci") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
    }
}

// MARK: - Riga azione (icona in colonna fissa da 18pt)

struct ActionRow: View {
    let icon: String
    let title: String
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
                    Button {
                        Task { await model.remove(task) }
                    } label: {
                        Image(systemName: "xmark")
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .help("Rimuovi il task (i file restano sulla box)")
                } else {
                    Text(percentText)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ProgressBarView(percent: task.progress * 100, tint: tint)
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

    private var tint: Color {
        switch task.status {
        case "downloading", "starting": .blue
        case "done", "seeding": .green
        case "error": .red
        case "stopped": .gray
        default: .orange
        }
    }

    private var metaText: String {
        var parts = [statoItaliano]
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

    private var statoItaliano: String {
        switch task.status {
        case "downloading": "in download"
        case "done": "completato"
        case "stopped": "in pausa"
        case "seeding": "seeding"
        case "error": task.error.map { "errore: \($0)" } ?? "errore"
        case "queued": "in coda"
        case "checking": "verifica"
        case "extracting": "estrazione"
        case "starting": "avvio"
        case "retry": "nuovo tentativo"
        default: task.status ?? "-"
        }
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
