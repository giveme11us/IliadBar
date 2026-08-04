import IliadBarDesign
import IliadboxKit
import SwiftUI

/// Sezione di atterraggio della finestra unica: il quadro della box composto
/// solo da dati già esistenti; ogni blocco porta alla propria sezione.
struct HomeView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        connectionCard
        HStack(alignment: .top, spacing: 16) {
          downloadsCard
          storageCard
        }
        HStack(alignment: .top, spacing: 16) {
          permissionsCard
          boxCard
        }
      }
      .padding(20)
    }
    .navigationTitle("Home")
    .task {
      await model.refresh()
      await model.refreshStorage()
      while !Task.isCancelled {
        await model.refreshBoxStats()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
      }
    }
  }

  // MARK: Connessione

  private var connectionCard: some View {
    GroupBox {
      if let connection = model.connection {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Circle()
              .fill(connection.isUp ? IliadTint.online : IliadTint.offline)
              .frame(width: 8, height: 8)
            Text(
              NetworkPresentation.connectionStateLabel(connection.isUp ? "up" : connection.state))
            if let media = connection.media {
              Text(media.uppercased())
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(IliadPalette.red)
            }
            Spacer()
            if let ipv4 = connection.ipv4 {
              Text(ipv4).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
          }
          HStack(spacing: 24) {
            rate(
              symbol: "arrow.down", value: connection.rateDown, bandwidth: connection.bandwidthDown,
              tint: IliadTint.trafficDown)
            rate(
              symbol: "arrow.up", value: connection.rateUp, bandwidth: connection.bandwidthUp,
              tint: IliadTint.trafficUp)
            Spacer()
            if let system = model.system {
              VStack(alignment: .trailing, spacing: 3) {
                if let uptime = system.uptimeVal {
                  Label(Format.uptime(uptime), systemImage: "clock")
                }
                if let temperature = system.maxTemperature {
                  Label("\(temperature) °C", systemImage: "thermometer.medium")
                }
              }
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
            }
          }
        }
        .padding(6)
      } else {
        HStack {
          Spacer()
          ProgressView().controlSize(.small)
          Text("Leggo lo stato della linea…").font(.footnote).foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.vertical, 14)
      }
    } label: {
      Text("Connessione").fontWeight(.semibold)
    }
  }

  private func rate(symbol: String, value: Int64?, bandwidth: Int64?, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(tint)
        Text("\(Format.bytes(value ?? 0))/s")
          .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
      }
      ProgressBarView(
        percent: ConnectionStatus.usagePercent(rate: value, bandwidth: bandwidth), tint: tint
      )
      .frame(width: 140)
    }
  }

  // MARK: Download

  private var downloadsCard: some View {
    sectionCard(
      title: "Download", destination: .download,
      content: {
        if model.activeTasks.isEmpty {
          Text("Nessun download attivo").font(.footnote).foregroundStyle(.secondary)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("\(model.activeTasks.count) attivi")
              .font(.footnote).foregroundStyle(IliadPalette.blue)
            ForEach(model.activeTasks.prefix(2)) { task in
              VStack(alignment: .leading, spacing: 3) {
                Text(task.name ?? "…").font(.caption).lineLimit(1).truncationMode(.middle)
                ProgressBarView(
                  percent: task.progress * 100, tint: IliadTint.downloadStatus(task.status))
              }
            }
          }
        }
      })
  }

  // MARK: Archivi

  private var storageCard: some View {
    sectionCard(
      title: "Archivi", destination: .file,
      content: {
        if model.storageDisks.isEmpty {
          Text("Informazioni archivi non disponibili").font(.footnote).foregroundStyle(.secondary)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(model.storageDisks) { disk in
              VStack(alignment: .leading, spacing: 3) {
                Text(disk.name ?? disk.model ?? "Archivio").font(.caption).lineLimit(1)
                let partitions = disk.partitions ?? []
                let total = partitions.compactMap(\.totalBytes).reduce(0, +)
                let free = partitions.compactMap(\.freeBytes).reduce(0, +)
                if total > 0 {
                  ProgressBarView(
                    percent: Double(total - free) / Double(total) * 100, tint: IliadPalette.violet)
                  Text("\(Format.bytes(free)) liberi di \(Format.bytes(total))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      })
  }

  // MARK: Permessi

  private var permissionsCard: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 7) {
        permissionRow("Impostazioni rete", granted: model.networkSettingsAllowed)
        permissionRow("Controllo parentale", granted: model.parentalControlAllowed)
        if !model.networkSettingsAllowed || !model.parentalControlAllowed {
          Text("I permessi si concedono dall'interfaccia web della iliadbox.")
            .font(.caption2).foregroundStyle(.tertiary)
        }
      }
      .padding(6)
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Text("Permessi").fontWeight(.semibold)
    }
  }

  private func permissionRow(_ title: LocalizedStringKey, granted: Bool) -> some View {
    HStack(spacing: 6) {
      Image(systemName: granted ? "checkmark.circle.fill" : "lock.fill")
        .foregroundStyle(granted ? IliadTint.online : Color.secondary)
        .imageScale(.small)
      Text(title).font(.footnote)
      Spacer()
      Text(granted ? "concesso" : "solo lettura")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: Box

  private var boxCard: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 7) {
        if let system = model.system {
          if let name = system.modelName {
            LabeledContent("Modello", value: name)
          }
          if let firmware = system.firmwareVersion {
            LabeledContent("Firmware", value: firmware)
          }
        }
        if let profile = model.profiles.first(where: { $0.id == model.activeProfileID }) {
          if let api = profile.apiVersion {
            LabeledContent("API", value: api)
          }
        }
      }
      .font(.footnote)
      .padding(6)
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Text(activeBoxName).fontWeight(.semibold)
    }
  }

  private var activeBoxName: String {
    model.profiles.first { $0.id == model.activeProfileID }?.name ?? "iliadbox"
  }

  // MARK: Card con destinazione

  private func sectionCard(
    title: LocalizedStringKey, destination: MainSection, @ViewBuilder content: () -> some View
  ) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 8) {
        content()
      }
      .padding(6)
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      HStack {
        Text(title).fontWeight(.semibold)
        Spacer()
        Button("Apri") { model.mainWindowSection = destination }
          .buttonStyle(.plain)
          .font(.caption)
          .foregroundStyle(IliadPalette.red)
      }
    }
  }
}
