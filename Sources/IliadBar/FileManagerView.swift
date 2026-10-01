import IliadBarDesign
import IliadboxKit
import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

struct FileManagerView: View {
  @ObservedObject var model: AppModel
  @State private var selection: Set<String> = []
  #if canImport(UIKit)
    @State private var iosSelection: FsEntry.ID?
    @State private var showUploadImporter = false
  #endif
  @State private var showNewFolder = false
  @State private var showRename = false
  @State private var showDelete = false
  @State private var transferMode: TransferMode?
  @State private var activeOperationTask: Task<Void, Never>?
  @State private var showShareLinks = false
  @State private var sortOrder = [KeyPathComparator(\FsEntry.name)]
  @State private var dropTargeted = false

  enum TransferMode: String, Identifiable {
    case copy, move
    var id: String { rawValue }

    var title: String {
      switch self {
      case .copy: NSLocalizedString("Copia", comment: "Transfer mode")
      case .move: NSLocalizedString("Sposta", comment: "Transfer mode")
      }
    }
  }

  /// File locale da consegnare a uno share sheet iOS.
  #if canImport(UIKit)
    struct ShareFileItem: Identifiable {
      let url: URL
      var id: String { url.absoluteString }
    }
  #endif

  var body: some View {
    VStack(spacing: 0) {
      storageStrip
      Divider()
      browserHeader
      Divider()
      entriesTable
      operationFooter
    }
    .navigationTitle("File")
    .toolbar { toolbar }
    .task {
      await model.openFilesRootIfNeeded()
      await model.refreshStorage()
      await model.refreshShareLinks()
    }
    .sheet(isPresented: $showNewFolder) {
      NameEntrySheet(title: "Nuova cartella", initialValue: "") { name in
        Task { await model.createFolder(named: name) }
      }
    }
    .sheet(isPresented: $showRename) {
      if let entry = renameTarget {
        NameEntrySheet(title: "Rinomina", initialValue: entry.name) { name in
          runOperation { await model.rename(entry, to: name) }
        }
      }
    }
    .sheet(item: $transferMode) { mode in
      DestinationPickerView(model: model, mode: mode.title) { destination, conflictMode in
        let entries = actionableEntries
        runOperation {
          await model.transferEntries(
            entries,
            to: destination,
            move: mode == .move,
            conflictMode: conflictMode
          )
        }
      }
    }
    .sheet(isPresented: $showShareLinks) {
      ShareLinksView(model: model)
    }
    .confirmationDialog(
      "Alcuni file esistono già in questa cartella",
      isPresented: Binding(
        get: { model.pendingUpload != nil },
        set: { if !$0 { model.pendingUpload = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Sostituisci") { runOperation { await model.resolvePendingUpload(.replace) } }
      Button("Riprendi i file parziali") {
        runOperation { await model.resolvePendingUpload(.resume) }
      }
      Button("Salta quelli esistenti") {
        runOperation { await model.resolvePendingUpload(.skipExisting) }
      }
      Button("Annulla", role: .cancel) { model.pendingUpload = nil }
    } message: {
      Text(conflictMessage)
    }
    .confirmationDialog(
      "Eliminare \(actionableEntries.count) elementi dalla iliadbox?",
      isPresented: $showDelete,
      titleVisibility: .visible
    ) {
      Button("Elimina definitivamente", role: .destructive) {
        let entries = actionableEntries
        #if canImport(AppKit)
          selection.removeAll()
        #else
          iosSelection = nil
        #endif
        runOperation { await model.removeEntries(entries) }
      }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("Questa azione elimina file e cartelle dalla box e non può essere annullata.")
    }
  }

  #if canImport(UIKit)
    /// Le azioni della toolbar iOS lavorano sulla selezione singola della
    /// lista; i percorsi multipli restano un gesto da desktop.
    private var iosSelectedEntry: FsEntry? {
      guard let id = iosSelection else { return nil }
      return model.entries.first { $0.id == id }
    }
  #endif

  private var selectedEntries: [FsEntry] {
    model.entries.filter { selection.contains($0.id) }
  }

  /// Le cartelle restano in testa qualunque sia l'ordinamento scelto: è
  /// l'unica gerarchia che l'utente si aspetta sempre.
  private var sortedEntries: [FsEntry] {
    let sorted = model.entries.sorted(using: sortOrder)
    return sorted.filter(\.isDirectory) + sorted.filter { !$0.isDirectory }
  }

  private var entriesTable: some View {
    #if canImport(AppKit)
      macOSTable
    #elseif canImport(UIKit)
      iosList
    #endif
  }

  #if canImport(AppKit)
    private var macOSTable: some View {
      Table(sortedEntries, selection: $selection, sortOrder: $sortOrder) {
        TableColumn("Nome", value: \.name) { entry in
          HStack(spacing: 8) {
            Image(systemName: entry.isDirectory ? "folder.fill" : icon(for: entry))
              .foregroundStyle(entry.isDirectory ? IliadPalette.blue : Color.secondary)
              .frame(width: 18)
            Text(entry.name).lineLimit(1).truncationMode(.middle)
          }
        }
        TableColumn("Dimensione", value: \.sortableSize) { entry in
          Text(entry.isDirectory ? "—" : Format.bytes(entry.size ?? 0))
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .width(min: 90, ideal: 110)
        TableColumn("Modifica", value: \.sortableModification) { entry in
          if let modification = entry.modification, modification > 0 {
            Text(Date(timeIntervalSince1970: TimeInterval(modification)), style: .date)
              .font(.callout)
              .foregroundStyle(.secondary)
          } else {
            Text("—").foregroundStyle(.tertiary)
          }
        }
        .width(min: 110, ideal: 140)
      }
      .contextMenu(forSelectionType: FsEntry.ID.self) { ids in
        if let entry = model.entries.first(where: { ids.first == $0.id }) {
          contextMenu(entry)
        }
      } primaryAction: { ids in
        guard let entry = model.entries.first(where: { ids.first == $0.id }), entry.isDirectory
        else { return }
        Task { await model.enter(entry) }
      }
      .overlay {
        if model.filesLoading {
          ProgressView()
        } else if model.entries.isEmpty {
          ContentUnavailableView("Cartella vuota", systemImage: "folder")
        }
      }
      .onDeleteCommand {
        if !selection.isEmpty { showDelete = true }
      }
      .onKeyPress(.return) {
        guard selection.count == 1, let entry = selectedEntries.first, entry.isDirectory else {
          return .ignored
        }
        Task { await model.enter(entry) }
        return .handled
      }
      // Trascinare dal Finder è il modo macOS di fare ciò che il bottone
      // "Carica…" già fa.
      .dropDestination(for: URL.self) { urls, _ in
        runOperation { await model.upload(urls) }
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
    }
  #endif

  #if canImport(UIKit)
    /// Browser file iOS: cartelle con tap, file con context menu e azioni
    /// veloci; selezione singola per Rinomina/Copia/Sposta della toolbar.
    private var iosList: some View {
      List(sortedEntries, selection: $iosSelection) { entry in
        row(entry)
          .tag(entry.id)
          .contentShape(Rectangle())
          .onTapGesture {
            if entry.isDirectory { Task { await model.enter(entry) } }
          }
          .contextMenu { contextMenu(entry) }
          .swipeActions {
            if !entry.isDirectory {
              Button {
                Task { await model.downloadToMac(entry) }
              } label: {
                Label("Scarica", systemImage: "arrow.down.circle")
              }
              .tint(IliadPalette.blue)
            }
            Button(role: .destructive) {
              iosSelection = entry.id
              showDelete = true
            } label: {
              Label("Elimina", systemImage: "trash")
            }
          }
      }
      .overlay {
        if model.filesLoading {
          ProgressView()
        } else if model.entries.isEmpty {
          ContentUnavailableView("Cartella vuota", systemImage: "folder")
        }
      }
      .fileImporter(
        isPresented: $showUploadImporter,
        allowedContentTypes: [.item],
        allowsMultipleSelection: true
      ) { result in
        if case .success(let urls) = result {
          runOperation { await model.upload(urls) }
        }
      }
      .sheet(item: shareItemBinding) { file in
        ActivityShareSheet(items: [file.url])
      }
    }

    private var shareItemBinding: Binding<ShareFileItem?> {
      Binding(
        get: { model.downloadedFileForSharing.map(ShareFileItem.init) },
        set: { if $0 == nil { model.downloadedFileForSharing = nil } }
      )
    }

    private func row(_ entry: FsEntry) -> some View {
      HStack(spacing: 10) {
        Image(systemName: entry.isDirectory ? "folder.fill" : icon(for: entry))
          .foregroundStyle(entry.isDirectory ? IliadPalette.blue : Color.secondary)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.name).lineLimit(1).truncationMode(.middle)
          Text(
            entry.isDirectory
              ? NSLocalizedString("Cartella", comment: "File browser")
              : Format.bytes(entry.size ?? 0)
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        Spacer()
      }
    }
  #endif

  private func icon(for entry: FsEntry) -> String {
    switch (entry.name as NSString).pathExtension.lowercased() {
    case "mkv", "mp4", "mov", "avi": "film"
    case "jpg", "jpeg", "png", "heic", "webp": "photo"
    case "mp3", "flac", "wav", "aac": "music.note"
    case "zip", "rar", "7z", "tar", "gz": "archivebox"
    case "torrent": "point.3.connected.trianglepath.dotted"
    case "pdf", "epub": "book"
    default: "doc"
    }
  }

  private var storageStrip: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 18) {
        if model.storageDisks.isEmpty {
          Label("Informazioni archivi non disponibili", systemImage: "internaldrive")
            .foregroundStyle(.secondary)
        }
        ForEach(model.storageDisks) { disk in
          VStack(alignment: .leading, spacing: 4) {
            Label(disk.name ?? disk.model ?? "Archivio", systemImage: "internaldrive")
              .font(.callout.weight(.medium))
            Text(storageSummary(disk))
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
  }

  private var browserHeader: some View {
    HStack(spacing: 8) {
      Button {
        Task { await model.goBack() }
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(model.crumbs.count <= 1)
      .accessibilityLabel("Indietro")
      HStack(spacing: 3) {
        if model.crumbs.count > 4 {
          Text("…").foregroundStyle(.tertiary)
          Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        // Le briciole sono bottoni: si risale con un click, non solo con
        // il pulsante Indietro.
        ForEach(Array(model.crumbs.enumerated().suffix(4)), id: \.element.id) { index, crumb in
          if index > max(0, model.crumbs.count - 4) {
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
          }
          Button {
            Task { await model.goTo(crumbIndex: index) }
          } label: {
            Text(crumb.name)
              .lineLimit(1)
              .foregroundStyle(
                index == model.crumbs.count - 1 ? Color.primary : Color.secondary)
          }
          .buttonStyle(.plain)
          .disabled(index == model.crumbs.count - 1)
        }
      }
      .font(.callout)
      Spacer()
      Text("\(model.entries.count) elementi")
        .font(.caption)
        .foregroundStyle(.secondary)
      Button {
        Task { await model.reloadFiles() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .accessibilityLabel("Aggiorna")
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItemGroup {
      Button {
        showNewFolder = true
      } label: {
        Label("Nuova cartella", systemImage: "folder.badge.plus")
      }
      #if canImport(AppKit)
        .keyboardShortcut("n", modifiers: .command)
      #endif
      Button {
        #if canImport(AppKit)
          runOperation { await model.chooseFilesToUpload() }
        #else
          showUploadImporter = true
        #endif
      } label: {
        Label("Carica…", systemImage: "arrow.up.doc")
      }
      #if canImport(AppKit)
        .help("Carica file nella cartella corrente")
      #endif
      Button {
        showShareLinks = true
      } label: {
        Label("Link condivisi", systemImage: "link")
      }
      Button {
        transferMode = .copy
      } label: {
        Label("Copia", systemImage: "doc.on.doc")
      }
      .disabled(!canTransferSelection)
      Button {
        transferMode = .move
      } label: {
        Label("Sposta", systemImage: "folder")
      }
      .disabled(!canTransferSelection)
      Button {
        showRename = true
      } label: {
        Label("Rinomina", systemImage: "pencil")
      }
      .disabled(renameTarget == nil)
      Button(role: .destructive) {
        showDelete = true
      } label: {
        Label("Elimina", systemImage: "trash")
      }
      .disabled(!hasDeletableSelection)
    }
  }

  private var canTransferSelection: Bool {
    #if canImport(AppKit)
      !selection.isEmpty
    #else
      iosSelectedEntry != nil
    #endif
  }

  private var hasDeletableSelection: Bool { canTransferSelection }

  /// Voce su cui agisce "Rinomina": una sola, su entrambe le piattaforme.
  private var renameTarget: FsEntry? {
    #if canImport(AppKit)
      selection.count == 1 ? selectedEntries.first : nil
    #else
      iosSelectedEntry
    #endif
  }

  /// Elementi coinvolti dalle azioni distruttive/di trasferimento.
  private var actionableEntries: [FsEntry] {
    #if canImport(AppKit)
      selectedEntries
    #else
      iosSelectedEntry.map { [$0] } ?? []
    #endif
  }

  @ViewBuilder
  private var operationFooter: some View {
    if let status = model.fileOperationStatus {
      Divider()
      HStack {
        ProgressView(value: model.uploadProgress)
          .controlSize(.small)
          .frame(width: 120)
        Text(status).font(.caption).foregroundStyle(.secondary)
        Spacer()
        if model.fileOperationCanCancel {
          Button("Annulla operazione", role: .cancel) {
            activeOperationTask?.cancel()
            Task { await model.cancelFileOperation() }
          }
        }
      }
      .padding(8)
    }
  }

  @ViewBuilder
  private func contextMenu(_ entry: FsEntry) -> some View {
    if entry.isDirectory {
      Button("Apri") { Task { await model.enter(entry) } }
    } else {
      Button("Copia sul dispositivo") { Task { await model.downloadToMac(entry) } }
    }
    Button("Crea link di condivisione") { Task { await model.createShareLink(for: entry) } }
    Divider()
    Button("Rinomina…") {
      selectEntry(entry.id)
      showRename = true
    }
    Button("Elimina…", role: .destructive) {
      selectEntry(entry.id)
      showDelete = true
    }
  }

  private func selectEntry(_ id: FsEntry.ID) {
    #if canImport(AppKit)
      selection = [id]
    #else
      iosSelection = id
    #endif
  }

  private var conflictMessage: String {
    let names = model.pendingUpload?.conflicting ?? []
    return names.prefix(5).joined(separator: ", ")
      + (names.count > 5 ? " (+\(names.count - 5))" : "")
  }

  private func storageSummary(_ disk: StorageDisk) -> String {
    let partitions = disk.partitions ?? []
    let total = partitions.compactMap(\.totalBytes).reduce(0, +)
    let free = partitions.compactMap(\.freeBytes).reduce(0, +)
    if total > 0 { return "\(Format.bytes(free)) liberi di \(Format.bytes(total))" }
    if let total = disk.totalBytes { return Format.bytes(total) }
    return disk.state ?? "stato sconosciuto"
  }

  private func runOperation(_ operation: @escaping @MainActor () async -> Void) {
    activeOperationTask?.cancel()
    activeOperationTask = Task {
      await operation()
      activeOperationTask = nil
    }
  }
}

private struct ShareLinksView: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var pendingRevocation: IliadboxKit.ShareLink?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Link condivisi").font(.title2.weight(.semibold))
        Spacer()
        Button("Chiudi") { dismiss() }
      }
      .padding(16)
      Divider()
      List(model.shareLinks) { link in
        HStack(spacing: 12) {
          Image(systemName: "link")
          VStack(alignment: .leading, spacing: 3) {
            Text(link.name ?? "Link senza nome")
            if let url = link.fullURL {
              Text(url).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
          }
          Spacer()
          if let url = link.fullURL {
            Button("Copia link") {
              #if canImport(AppKit)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
              #else
                UIPasteboard.general.string = url
              #endif
            }
          }
          Button("Revoca…", role: .destructive) { pendingRevocation = link }
        }
      }
      .overlay {
        if model.shareLinks.isEmpty {
          ContentUnavailableView(
            model.shareLinksAvailable
              ? "Nessun link condiviso" : "Condivisione non disponibile",
            systemImage: "link",
            description: Text(
              model.shareLinksAvailable
                ? "I link creati dai file compaiono qui."
                : "Questa iliadbox non espone i link di condivisione.")
          )
        }
      }
    }
    #if canImport(AppKit)
      .frame(minWidth: 620, minHeight: 360)
    #endif
    .task { await model.refreshShareLinks() }
    .confirmationDialog(
      "Revocare questo link?",
      isPresented: Binding(
        get: { pendingRevocation != nil },
        set: { if !$0 { pendingRevocation = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Revoca link", role: .destructive) {
        guard let link = pendingRevocation else { return }
        pendingRevocation = nil
        Task { await model.revokeShareLink(link) }
      }
      Button("Annulla", role: .cancel) { pendingRevocation = nil }
    } message: {
      Text("Chi possiede l’URL non potrà più accedere al file.")
    }
  }
}

private struct DestinationPickerView: View {
  @ObservedObject var model: AppModel
  let mode: String
  let choose: (String, FileConflictMode) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var stack = [Crumb(name: "Archivi", pathB64: IliadboxClient.rootPathB64)]
  @State private var folders: [FsEntry] = []
  @State private var conflictMode: FileConflictMode = .both

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button {
          goBack()
        } label: {
          Image(systemName: "chevron.left")
        }
        .disabled(stack.count == 1)
        .accessibilityLabel("Indietro")
        Text(stack.last?.name ?? "Archivi").font(.headline)
        Spacer()
      }
      .padding(12)
      Divider()
      List(folders) { folder in
        Button {
          stack.append(Crumb(name: folder.name, pathB64: folder.path))
          Task { await load() }
        } label: {
          Label(folder.name, systemImage: "folder.fill").frame(
            maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
      }
      Picker("In caso di conflitto", selection: $conflictMode) {
        Text("Mantieni entrambi").tag(FileConflictMode.both)
        Text("Sovrascrivi").tag(FileConflictMode.overwrite)
        Text("Mantieni il più recente").tag(FileConflictMode.recent)
        Text("Salta").tag(FileConflictMode.skip)
      }
      .padding(.horizontal, 12)
      HStack {
        Button("Annulla", role: .cancel) { dismiss() }
        Spacer()
        Button("\(mode) qui") {
          if let path = stack.last?.pathB64 { choose(path, conflictMode) }
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding(12)
    }
    #if canImport(AppKit)
      .frame(width: 430, height: 380)
    #endif
    .task { await load() }
  }

  private func load() async {
    guard let path = stack.last?.pathB64 else { return }
    folders = await model.listFolderForPicker(pathB64: path)
  }

  private func goBack() {
    guard stack.count > 1 else { return }
    stack.removeLast()
    Task { await load() }
  }
}

private struct NameEntrySheet: View {
  let title: LocalizedStringKey
  let submit: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var value: String

  init(title: LocalizedStringKey, initialValue: String, submit: @escaping (String) -> Void) {
    self.title = title
    self.submit = submit
    _value = State(initialValue: initialValue)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title).font(.title2.weight(.semibold))
      TextField("Nome", text: $value).textFieldStyle(.roundedBorder).onSubmit(done)
      HStack {
        Spacer()
        Button("Annulla", role: .cancel) { dismiss() }
        Button("Salva", action: done).keyboardShortcut(.defaultAction).disabled(cleaned.isEmpty)
      }
    }
    .padding(20)
    #if canImport(AppKit)
      .frame(width: 400)
    #endif
  }

  private var cleaned: String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
  private func done() {
    guard !cleaned.isEmpty else { return }
    submit(cleaned)
    dismiss()
  }
}
