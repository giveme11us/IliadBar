import IliadBarDesign
import IliadboxKit
import SwiftUI
import WidgetKit

private struct SnapshotEntry: TimelineEntry {
  let date: Date
  let snapshot: IliadBarWidgetSnapshot?
}

private struct SnapshotProvider: TimelineProvider {
  func placeholder(in context: Context) -> SnapshotEntry {
    SnapshotEntry(
      date: Date(),
      snapshot: .init(
        online: true, downloadRate: 12_500_000, uploadRate: 840_000, activeDownloads: 2,
        downloadProgress: 0.64))
  }
  func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
    completion(SnapshotEntry(date: Date(), snapshot: IliadBarWidgetSnapshotStore.load()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
    let entry = SnapshotEntry(date: Date(), snapshot: IliadBarWidgetSnapshotStore.load())
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
  }
}

private struct ConnectionWidgetView: View {
  let entry: SnapshotEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("iliadbox", systemImage: "network")
          .font(.headline)
        Spacer()
        Circle().fill(entry.snapshot?.online == true ? IliadTint.online : IliadTint.offline).frame(
          width: 8, height: 8)
      }
      Spacer()
      metric("arrow.down", entry.snapshot?.downloadRate ?? 0, color: IliadTint.trafficDown)
      metric("arrow.up", entry.snapshot?.uploadRate ?? 0, color: IliadTint.trafficUp)
      if let snapshot = entry.snapshot {
        Text("Aggiornato \(snapshot.updatedAt, style: .relative)")
          .font(.caption2).foregroundStyle(.secondary)
      } else {
        Text("Apri IliadBar per aggiornare")
          .font(.caption2).foregroundStyle(.secondary)
      }
    }
    .containerBackground(.fill.tertiary, for: .widget)
  }
  private func metric(_ icon: String, _ rate: Int64, color: Color) -> some View {
    HStack {
      Image(systemName: icon).foregroundStyle(color)
      Text(ByteCountFormatter.string(fromByteCount: rate, countStyle: .file) + "/s")
        .font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
    }
  }
}

private struct DownloadsWidgetView: View {
  let entry: SnapshotEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Download", systemImage: "arrow.down.circle.fill").font(.headline)
      Spacer()
      Text("\(entry.snapshot?.activeDownloads ?? 0)").font(
        .system(size: 34, weight: .bold, design: .rounded))
      if (entry.snapshot?.activeDownloads ?? 0) == 1 {
        Text("download attivo").foregroundStyle(.secondary)
      } else {
        Text("download attivi").foregroundStyle(.secondary)
      }
      if let progress = entry.snapshot?.downloadProgress {
        ProgressView(value: progress).tint(IliadPalette.red)
        Text(progress, format: .percent.precision(.fractionLength(0))).font(.caption)
          .monospacedDigit()
      }
    }
    .containerBackground(.fill.tertiary, for: .widget)
  }
}

private struct ConnectionWidget: Widget {
  let kind = "IliadBarConnection"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SnapshotProvider()) {
      ConnectionWidgetView(entry: $0)
    }
    .configurationDisplayName("Connessione iliadbox")
    .description("Stato e traffico della connessione.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private struct DownloadsWidget: Widget {
  let kind = "IliadBarDownloads"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SnapshotProvider()) { DownloadsWidgetView(entry: $0) }
      .configurationDisplayName("Download iliadbox")
      .description("Download attivi e avanzamento aggregato.")
      .supportedFamilies([.systemSmall])
  }
}

@main
struct IliadBarWidgets: WidgetBundle {
  var body: some Widget {
    ConnectionWidget()
    DownloadsWidget()
  }
}

#if DEBUG
  private struct IliadBarWidgetPreviews: PreviewProvider {
    static let entry = SnapshotEntry(
      date: Date(),
      snapshot: .init(
        online: true,
        downloadRate: 12_500_000,
        uploadRate: 840_000,
        activeDownloads: 2,
        downloadProgress: 0.64
      ))

    static var previews: some View {
      Group {
        ConnectionWidgetView(entry: entry)
          .previewContext(WidgetPreviewContext(family: .systemSmall))
          .previewDisplayName("Connessione")
        DownloadsWidgetView(entry: entry)
          .previewContext(WidgetPreviewContext(family: .systemSmall))
          .previewDisplayName("Download")
      }
    }
  }
#endif
