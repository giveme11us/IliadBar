import AppKit
import IliadboxKit
import SwiftUI

struct FileManagerView: View {
  @ObservedObject var model: AppModel
  @State private var selection: Set<String> = []
  @State private var showNewFolder = false
  @State private var showRename = false
  @State private var showDelete = false
  @State private var transferMode: TransferMode?
  @State private var activeOperationTask: Task<Void, Never>?
  @State private var showShareLinks = false

  enum TransferMode: String, Identifiable {
    case copy = "Copia"
    case move = "Sposta"
    var id: String { rawValue }
  }

  var body: some View {
    VStack(spacing: 0) {
      storageStrip
      Divider()
      browserHeader
      Divider()
      List(model.entries, selection: $selection) { entry in
        FileManagerRow(entry: entry)
          .tag(entry.id)
          .onTapGesture(count: 2) {
            if entry.isDirectory { Task { await model.enter(entry) } }
          }
          .contextMenu { contextMenu(entry) }
      }
      .overlay {
        if model.filesLoading {
          ProgressView()
        } else if model.entries.isEmpty {
          ContentUnavailableView("Cartella vuota", systemImage: "folder")
        }
      }
      operationFooter
    }
    .frame(minWidth: 720, minHeight: 500)
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
      if let entry = selectedEntries.first {
        NameEntrySheet(title: "Rinomina", initialValue: entry.name) { name in
          runOperation { await model.rename(entry, to: name) }
        }
      }
    }
    .sheet(item: $transferMode) { mode in
      DestinationPickerView(model: model, mode: mode.rawValue) { destination, conflictMode in
        let entries = selectedEntries
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
      "Eliminare \(selectedEntries.count) elementi dalla iliadbox?",
      isPresented: $showDelete,
      titleVisibility: .visible
    ) {
      Button("Elimina definitivamente", role: .destructive) {
        let entries = selectedEntries
        selection.removeAll()
        runOperation { await model.removeEntries(entries) }
      }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("Questa azione elimina file e cartelle dalla box e non può essere annullata.")
    }
  }

  private var selectedEntries: [FsEntry] {
    model.entries.filter { selection.contains($0.id) }
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
        ForEach(Array(model.crumbs.suffix(3).enumerated()), id: \.element.id) { index, crumb in
          if index > 0 {
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
          }
          Text(crumb.name).lineLimit(1)
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
      Menu {
        Button("Non sovrascrivere") {
          runOperation { await model.chooseAndUploadFiles(conflictMode: .missing) }
        }
        Button("Sovrascrivi") {
          runOperation { await model.chooseAndUploadFiles(conflictMode: .overwrite) }
        }
        Button("Riprendi file parziale") {
          runOperation { await model.chooseAndUploadFiles(conflictMode: .resume) }
        }
      } label: {
        Label("Carica", systemImage: "arrow.up.doc")
      }
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
      .disabled(selection.isEmpty)
      Button {
        transferMode = .move
      } label: {
        Label("Sposta", systemImage: "folder")
      }
      .disabled(selection.isEmpty)
      Button {
        showRename = true
      } label: {
        Label("Rinomina", systemImage: "pencil")
      }
      .disabled(selection.count != 1)
      Button(role: .destructive) {
        showDelete = true
      } label: {
        Label("Elimina", systemImage: "trash")
      }
      .disabled(selection.isEmpty)
    }
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
      Button("Copia sul Mac") { Task { await model.downloadToMac(entry) } }
    }
    Button("Crea link di condivisione") { Task { await model.createShareLink(for: entry) } }
    Divider()
    Button("Rinomina…") {
      selection = [entry.id]
      showRename = true
    }
    Button("Elimina…", role: .destructive) {
      selection = [entry.id]
      showDelete = true
    }
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
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(url, forType: .string)
            }
          }
          Button("Revoca…", role: .destructive) { pendingRevocation = link }
        }
      }
      .overlay {
        if model.shareLinks.isEmpty {
          ContentUnavailableView("Nessun link condiviso", systemImage: "link")
        }
      }
    }
    .frame(minWidth: 620, minHeight: 360)
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

private struct FileManagerRow: View {
  let entry: FsEntry

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: entry.isDirectory ? "folder.fill" : icon)
        .foregroundStyle(entry.isDirectory ? Color.accentColor : Color.secondary)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.name).lineLimit(1)
        if let modification = entry.modification {
          Text(Date(timeIntervalSince1970: TimeInterval(modification)), style: .date)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      if !entry.isDirectory, let size = entry.size {
        Text(Format.bytes(size)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 3)
  }

  private var icon: String {
    switch (entry.name as NSString).pathExtension.lowercased() {
    case "mkv", "mp4", "mov": "film"
    case "jpg", "jpeg", "png", "heic": "photo"
    case "mp3", "flac", "wav": "music.note"
    case "zip", "rar", "7z": "archivebox"
    default: "doc"
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
    .frame(width: 430, height: 380)
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
  let title: String
  let submit: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var value: String

  init(title: String, initialValue: String, submit: @escaping (String) -> Void) {
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
    .frame(width: 400)
  }

  private var cleaned: String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
  private func done() {
    guard !cleaned.isEmpty else { return }
    submit(cleaned)
    dismiss()
  }
}
