import Foundation

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
