import IliadBarDesign
import IliadboxKit
import SwiftUI

private enum DownloadFilter: String, CaseIterable, Identifiable {
  case all, active, finished, errors
  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .all: "Tutti"
    case .active: "Attivi"
    case .finished: "Completati"
    case .errors: "Errori"
    }
  }
}

private enum DownloadSort: String, CaseIterable, Identifiable {
  case recent, name, progress, size, speed
  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .recent: "Più recenti"
    case .name: "Nome"
    case .progress: "Avanzamento"
    case .size: "Dimensione"
    case .speed: "Velocità"
    }
  }

  func areInOrder(_ lhs: DownloadTask, _ rhs: DownloadTask) -> Bool {
    switch self {
    case .recent: (lhs.createdTimestamp ?? Int64(lhs.id)) > (rhs.createdTimestamp ?? Int64(rhs.id))
    case .name: (lhs.name ?? "").localizedStandardCompare(rhs.name ?? "") == .orderedAscending
    case .progress: lhs.progress > rhs.progress
    case .size: (lhs.size ?? 0) > (rhs.size ?? 0)
    case .speed: (lhs.rxRate ?? 0) > (rhs.rxRate ?? 0)
    }
  }
}

struct DownloadManagerView: View {
  @ObservedObject var model: AppModel
  @State private var selection: Int?
  @State private var search = ""
  @State private var filter: DownloadFilter = .all
  @State private var sort: DownloadSort = .recent
  @State private var showAddURL = false
  @State private var pendingRemoval: DownloadTask?
  @State private var dropTargeted = false

  var body: some View {
    // HSplitView e non NavigationSplitView: il sidebar della finestra è uno
    // solo (MainWindowView) e annidarne un secondo duplicherebbe i controlli.
    HSplitView {
      VStack(spacing: 0) {
        Picker("Filtro", selection: $filter) {
          ForEach(DownloadFilter.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(10)

        List(filteredTasks, selection: $selection) { task in
          DownloadListRow(task: task)
            .tag(task.id)
            .onTapGesture(count: 2) { Task { await model.revealInFiles(task) } }
            .contextMenu { taskMenu(task) }
        }
        .searchable(text: $search, prompt: "Cerca download")
        .onDeleteCommand {
          if let task = selectedTask { pendingRemoval = task }
        }
        .overlay {
          if filteredTasks.isEmpty {
            ContentUnavailableView(
              search.isEmpty ? "Nessun download" : "Nessun risultato",
              systemImage: search.isEmpty ? "arrow.down.circle" : "magnifyingglass"
            )
          }
        }
      }
      .frame(minWidth: 280, idealWidth: 330, maxWidth: 460)

      Group {
        if let task = selectedTask {
          DownloadDetailView(task: task, model: model) {
            pendingRemoval = task
          }
          .id(task.id)
          .task { await model.loadDownloadDetails(task) }
        } else {
          ContentUnavailableView(
            "Seleziona un download",
            systemImage: "arrow.down.circle",
            description: Text("Qui trovi file, tracker, peer e stato dei blocchi.")
          )
        }
      }
      .frame(minWidth: 380, maxWidth: .infinity)
    }
    // Trascinare un .torrent qui equivale ad "Apri torrent o NZB".
    .dropDestination(for: URL.self) { urls, _ in
      Task { await model.addDownloadFiles(urls) }
      return true
    } isTargeted: {
      dropTargeted = $0
    }
    .overlay {
      if dropTargeted {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(IliadPalette.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
          .padding(4)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .navigationTitle("Download")
    .toolbar {
      ToolbarItemGroup {
        Menu {
          Picker("Ordina per", selection: $sort) {
            ForEach(DownloadSort.allCases) { Text($0.title).tag($0) }
          }
          .pickerStyle(.inline)
        } label: {
          Label("Ordina", systemImage: "arrow.up.arrow.down")
        }
        .help("Ordina i download")
        Button {
          showAddURL = true
        } label: {
          Label("Aggiungi URL", systemImage: "link.badge.plus")
        }
        Button {
          Task { await model.chooseAndAddDownloadFile() }
        } label: {
          Label("Apri torrent o NZB", systemImage: "doc.badge.plus")
        }
        Button {
          Task { await model.refresh() }
        } label: {
          Label("Aggiorna", systemImage: "arrow.clockwise")
        }
      }
    }
    .task { await model.refresh() }
    .onChange(of: selection) { _, id in
      guard let id, let task = model.tasks.first(where: { $0.id == id }) else { return }
      Task { await model.loadDownloadDetails(task) }
    }
    .sheet(isPresented: $showAddURL) { AddDownloadURLView(model: model) }
    .confirmationDialog(
      "Rimuovere \(pendingRemoval?.name ?? "il download")?",
      isPresented: Binding(
        get: { pendingRemoval != nil },
        set: { if !$0 { pendingRemoval = nil } }
      ),
      titleVisibility: .visible
    ) {
      if let task = pendingRemoval {
        Button("Rimuovi solo il task") { Task { await model.remove(task) } }
        Button("Rimuovi task e file", role: .destructive) {
          Task { await model.remove(task, eraseFiles: true) }
        }
      }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("I file vengono eliminati dalla box solo scegliendo l’azione distruttiva.")
    }
  }

  private var selectedTask: DownloadTask? {
    guard let selection else { return nil }
    return model.tasks.first { $0.id == selection }
  }

  private var filteredTasks: [DownloadTask] {
    model.tasks.filter { task in
      let matchesFilter =
        switch filter {
        case .all: true
        case .active: task.isActive
        case .finished: task.isFinished
        case .errors: task.hasFailed
        }
      let matchesSearch =
        search.isEmpty || (task.name ?? "").localizedCaseInsensitiveContains(search)
      return matchesFilter && matchesSearch
    }
    .sorted(by: sort.areInOrder)
  }

  @ViewBuilder
  private func taskMenu(_ task: DownloadTask) -> some View {
    Button(task.status == "stopped" ? "Riprendi" : "Pausa") {
      Task { await model.togglePause(task) }
    }
    if task.hasFailed {
      Button("Riprova") { Task { await model.retry(task) } }
    }
    if task.downloadDirectory?.isEmpty == false {
      Button("Mostra nei File") { Task { await model.revealInFiles(task) } }
    }
    Divider()
    Button("Rimuovi…", role: .destructive) { pendingRemoval = task }
  }
}

private struct DownloadListRow: View {
  let task: DownloadTask

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Image(systemName: statusSymbol)
          .foregroundStyle(statusColor)
          .frame(width: 16)
        Text(task.name ?? "Download \(task.id)")
          .lineLimit(1)
        Spacer()
        Text("\(Int(task.progress * 100))%")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      ProgressView(value: task.progress)
        .tint(statusColor)
      HStack {
        Text(DownloadPresentation.statusLabel(task))
        Spacer()
        if task.isActive { Text("↓ \(Format.bytes(task.rxRate ?? 0))/s") }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }

  private var statusSymbol: String {
    if task.hasFailed { return "exclamationmark.triangle.fill" }
    if task.isFinished { return "checkmark.circle.fill" }
    if task.status == "stopped" { return "pause.circle.fill" }
    return "arrow.down.circle.fill"
  }

  private var statusColor: Color {
    if task.hasFailed { return IliadPalette.red }
    if task.isFinished { return IliadPalette.green }
    if task.status == "stopped" { return IliadPalette.amber }
    return IliadPalette.blue
  }
}

private struct DownloadDetailView: View {
  let task: DownloadTask
  @ObservedObject var model: AppModel
  let requestRemoval: () -> Void
  @State private var tab = "File"

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(18)
      Divider()
      Picker("Dettagli", selection: $tab) {
        Text("File").tag("File")
        if task.type == "bt" {
          Text("Tracker").tag("Tracker")
          Text("Peer").tag("Peer")
          Text("Blocchi").tag("Blocchi")
        }
      }
      .pickerStyle(.segmented)
      .padding(12)

      Group {
        switch tab {
        case "Tracker": trackers
        case "Peer": peers
        case "Blocchi": pieces
        default: files
        }
      }
      .overlay { if model.detailLoading { ProgressView() } }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(model.detailTask?.name ?? task.name ?? "Download \(task.id)")
        .font(.title2.weight(.semibold))
        .lineLimit(2)
      ProgressView(value: model.detailTask?.progress ?? task.progress)
        .tint(IliadTint.downloadStatus(task.status))
      HStack(spacing: 20) {
        metric("Ricevuti", Format.bytes(model.detailTask?.rxBytes ?? task.rxBytes ?? 0))
        metric("Dimensione", Format.bytes(model.detailTask?.size ?? task.size ?? 0))
        metric("Velocità", "\(Format.bytes(model.detailTask?.rxRate ?? task.rxRate ?? 0))/s")
        metric("ETA", (model.detailTask?.eta ?? task.eta).map(Format.duration) ?? "—")
      }
      HStack {
        Button(task.status == "stopped" ? "Riprendi" : "Pausa") {
          Task { await model.togglePause(task) }
        }
        if task.hasFailed {
          Button("Riprova") { Task { await model.retry(task) } }
        }
        if task.downloadDirectory?.isEmpty == false {
          Button("Mostra nei File") { Task { await model.revealInFiles(task) } }
        }
        Menu("Priorità: \(DownloadPresentation.priorityLabel(task.ioPriority))") {
          ForEach(["low", "normal", "high"], id: \.self) { priority in
            Button(DownloadPresentation.priorityLabel(priority)) {
              Task { await model.setPriority(priority, for: task) }
            }
          }
        }
        Spacer()
        Button("Rimuovi…", role: .destructive, action: requestRemoval)
      }
    }
  }

  private func metric(_ label: LocalizedStringKey, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.callout.monospacedDigit())
    }
  }

  private var files: some View {
    List(model.detailFiles) { file in
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(file.name).lineLimit(1)
          ProgressView(value: file.progress).tint(IliadPalette.blue)
        }
        Text(Format.bytes(file.size ?? 0))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        Menu(DownloadPresentation.priorityLabel(file.priority)) {
          ForEach(["no_dl", "low", "normal", "high"], id: \.self) { priority in
            Button(DownloadPresentation.priorityLabel(priority)) {
              Task { await model.setFilePriority(priority, file: file) }
            }
          }
        }
        .frame(width: 110)
      }
    }
    .overlay {
      if model.detailFiles.isEmpty && !model.detailLoading {
        ContentUnavailableView("Nessun file", systemImage: "doc")
      }
    }
  }

  private var trackers: some View {
    List(model.detailTrackers) { tracker in
      HStack {
        VStack(alignment: .leading) {
          Text(tracker.announce).lineLimit(1)
          Text(tracker.status ?? "sconosciuto").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Text("\(tracker.seeders ?? 0) seed · \(tracker.leechers ?? 0) peer")
          .font(.caption.monospacedDigit())
      }
    }
  }

  private var peers: some View {
    List(model.detailPeers) { peer in
      HStack {
        Text(peer.countryCode ?? "??").frame(width: 28)
        VStack(alignment: .leading) {
          Text("\(peer.host):\(peer.port ?? 0)").font(.body.monospaced())
          Text(peer.client ?? peer.state ?? "peer").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Text("↓ \(Format.bytes(peer.rxRate ?? 0))/s").font(.caption.monospacedDigit())
      }
    }
  }

  private var pieces: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let pieces = model.detailPieces, !pieces.isEmpty {
        let completed = pieces.filter { $0 == "X" }.count
        ProgressView(value: Double(completed), total: Double(pieces.count))
          .tint(IliadPalette.blue)
        Text("\(completed) di \(pieces.count) blocchi completati")
          .font(.callout.monospacedDigit())
        PiecesGrid(pieces: pieces)
      } else {
        ContentUnavailableView("Stato blocchi non disponibile", systemImage: "square.grid.3x3")
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

/// Mappa dei blocchi come griglia: un Canvas unico regge decine di migliaia
/// di celle dove altrettante view SwiftUI non arriverebbero.
private struct PiecesGrid: View {
  let pieces: String
  private let cell: CGFloat = 6

  var body: some View {
    let states = Array(pieces)
    GeometryReader { geometry in
      let columns = max(1, Int(geometry.size.width / cell))
      let rows = Int(ceil(Double(states.count) / Double(columns)))
      ScrollView {
        Canvas { context, _ in
          for (index, state) in states.enumerated() {
            let rect = CGRect(
              x: CGFloat(index % columns) * cell + 0.5,
              y: CGFloat(index / columns) * cell + 0.5,
              width: cell - 1,
              height: cell - 1
            )
            context.fill(
              Path(roundedRect: rect, cornerRadius: 1),
              with: .color(state == "X" ? IliadPalette.blue : Color.primary.opacity(0.14))
            )
          }
        }
        .frame(height: CGFloat(rows) * cell)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 280)
    .accessibilityLabel("Mappa dei blocchi scaricati")
  }
}

private struct AddDownloadURLView: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var url = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Aggiungi download").font(.title2.weight(.semibold))
      TextField("Magnet, HTTP o FTP", text: $url)
        .textFieldStyle(.roundedBorder)
        .onSubmit(add)
      HStack {
        Spacer()
        Button("Annulla", role: .cancel) { dismiss() }
        Button("Aggiungi", action: add)
          .keyboardShortcut(.defaultAction)
          .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(20)
    .frame(width: 480)
  }

  private func add() {
    let value = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    dismiss()
    Task { await model.addURL(value) }
  }
}
