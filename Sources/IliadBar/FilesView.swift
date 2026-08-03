import SwiftUI
import IliadboxKit

/// Tab "File": naviga la cartella download della box (fs/ dell'API).
/// I file si possono copiare in ~/Downloads del Mac; per tutto il resto c'è l'SMB.
struct FilesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            breadcrumb

            if model.filesLoading, model.entries.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if model.entries.isEmpty {
                Text("Cartella vuota")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                entryList
            }

            Divider()
            ActionRow(icon: "network", title: "Apri condivisione SMB nel Finder") {
                model.openSMBShare()
            }
        }
        .task { await model.openFilesRootIfNeeded() }
    }

    // MARK: Breadcrumb

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            if model.crumbs.count > 1 {
                Button {
                    Task { await model.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help("Indietro")
            }
            Text(model.crumbs.last?.name ?? "File")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if model.filesLoading {
                ProgressView().controlSize(.mini)
            }
            Button {
                Task { await model.reloadFiles() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Aggiorna")
        }
    }

    // MARK: Lista

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(model.entries) { entry in
                    EntryRow(entry: entry, model: model)
                }
            }
        }
        .frame(height: min(CGFloat(model.entries.count) * 26, 260))
    }
}

private struct EntryRow: View {
    let entry: FsEntry
    let model: AppModel
    @State private var hovering = false

    var body: some View {
        Button {
            if entry.isDirectory {
                Task { await model.enter(entry) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: entry.isDirectory ? "folder.fill" : iconForFile)
                    .imageScale(.medium)
                    .foregroundStyle(entry.isDirectory ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                Text(entry.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                } else if hovering {
                    Button {
                        Task { await model.downloadToMac(entry) }
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .help("Copia in ~/Downloads del Mac")
                } else if let size = entry.size, size > 0 {
                    Text(Format.bytes(size))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
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

    private var iconForFile: String {
        let ext = (entry.name as NSString).pathExtension.lowercased()
        switch ext {
        case "mkv", "mp4", "avi", "mov": return "film"
        case "mp3", "flac", "aac", "wav": return "music.note"
        case "jpg", "jpeg", "png", "heic", "webp": return "photo"
        case "iso", "img", "dmg": return "opticaldisc"
        case "zip", "rar", "7z", "tar", "gz": return "shippingbox"
        case "torrent": return "point.3.connected.trianglepath.dotted"
        case "pdf", "epub": return "book"
        default: return "doc"
        }
    }
}
