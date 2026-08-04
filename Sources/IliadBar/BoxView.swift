import IliadBarDesign
import IliadboxKit
import SwiftUI

/// Tab "Box": stato connessione con velocità live e informazioni di sistema.
struct BoxView: View {
  @ObservedObject var model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Group {
      connectionSection
      Divider()
      systemSection
      Divider()
      Button {
        model.mainWindowSection = .devices
        openWindow(id: IliadBarWindow.main)
      } label: {
        Label("Apri Rete", systemImage: "network")
      }
      .buttonStyle(.plain)
      Button {
        model.mainWindowSection = .nat
        openWindow(id: IliadBarWindow.main)
      } label: {
        Label("Apri Servizi", systemImage: "server.rack")
      }
      .buttonStyle(.plain)
    }
    // Poll serrato solo finché la tab è visibile (il .task si cancella da solo).
    .task {
      while !Task.isCancelled {
        await model.refreshBoxStats()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
      }
    }
  }

  // MARK: Connessione

  @ViewBuilder
  private var connectionSection: some View {
    Text("CONNESSIONE")
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)

    if let connection = model.connection {
      HStack(spacing: 5) {
        Circle()
          .fill(connection.isUp ? IliadTint.online : IliadTint.offline)
          .frame(width: 7, height: 7)
        Text(NetworkPresentation.connectionStateLabel(connection.isUp ? "up" : connection.state))
          .font(.callout)
        if let media = connection.media {
          Text("· \(media.uppercased())")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if let ipv4 = connection.ipv4 {
          Text(ipv4)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      RateRow(
        symbol: "arrow.down",
        tint: IliadTint.trafficDown,
        rate: connection.rateDown,
        bandwidth: connection.bandwidthDown
      )
      RateRow(
        symbol: "arrow.up",
        tint: IliadTint.trafficUp,
        rate: connection.rateUp,
        bandwidth: connection.bandwidthUp
      )
    } else {
      loadingRow
    }
  }

  // MARK: Sistema

  @ViewBuilder
  private var systemSection: some View {
    Text("SISTEMA")
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)

    if let system = model.system {
      if let model = system.modelName {
        InfoRow(label: "Modello", value: model)
      }
      if let firmware = system.firmwareVersion {
        InfoRow(label: "Firmware", value: firmware)
      }
      if let uptimeVal = system.uptimeVal {
        InfoRow(label: "Uptime", value: Format.uptime(uptimeVal))
      } else if let uptime = system.uptime {
        InfoRow(label: "Uptime", value: uptime)
      }
      if let temperature = system.maxTemperature {
        InfoRow(label: "Temperatura", value: "\(temperature) °C")
      }
    } else {
      loadingRow
    }
  }

  private var loadingRow: some View {
    HStack {
      Spacer()
      ProgressView().controlSize(.small)
      Spacer()
    }
    .padding(.vertical, 6)
  }
}

/// Velocità istantanea con barra d'uso della banda.
private struct RateRow: View {
  let symbol: String
  let tint: Color
  let rate: Int64?
  let bandwidth: Int64?

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Image(systemName: symbol)
          .imageScale(.small)
          .foregroundStyle(.secondary)
          .frame(width: 14)
        Text("\(Format.bytes(rate ?? 0))/s")
          .font(.footnote)
          .monospacedDigit()
        Spacer()
        if let bandwidth, bandwidth > 0 {
          Text(Format.bits(bandwidth))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      ProgressBarView(
        percent: ConnectionStatus.usagePercent(rate: rate, bandwidth: bandwidth),
        tint: tint
      )
    }
  }
}

private struct InfoRow: View {
  let label: LocalizedStringKey
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.footnote)
        .textSelection(.enabled)
    }
  }
}
