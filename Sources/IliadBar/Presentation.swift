import Foundation
import IliadboxKit

/// Traduzione del vocabolario API (stati e priorità dei task) in etichette
/// localizzate: unico punto condiviso da pannello e finestre.
enum DownloadPresentation {
  static func statusLabel(_ task: DownloadTask) -> String {
    switch task.status {
    case "downloading": NSLocalizedString("in download", comment: "Download status")
    case "done": NSLocalizedString("completato", comment: "Download status")
    case "stopped": NSLocalizedString("in pausa", comment: "Download status")
    case "seeding": NSLocalizedString("seeding", comment: "Download status")
    case "queued": NSLocalizedString("in coda", comment: "Download status")
    case "checking": NSLocalizedString("verifica", comment: "Download status")
    case "repairing": NSLocalizedString("riparazione", comment: "Download status")
    case "extracting": NSLocalizedString("estrazione", comment: "Download status")
    case "starting": NSLocalizedString("avvio", comment: "Download status")
    case "retry": NSLocalizedString("nuovo tentativo", comment: "Download status")
    case "error": errorLabel(task.error)
    default: task.status ?? "—"
    }
  }

  static func priorityLabel(_ raw: String?) -> String {
    switch raw {
    case "low": NSLocalizedString("bassa", comment: "Download priority")
    case "high": NSLocalizedString("alta", comment: "Download priority")
    case "no_dl": NSLocalizedString("non scaricare", comment: "Download priority")
    default: NSLocalizedString("normale", comment: "Download priority")
    }
  }

  private static func errorLabel(_ error: String?) -> String {
    guard let error, error != "none" else {
      return NSLocalizedString("errore", comment: "Download status")
    }
    return String(
      format: NSLocalizedString("errore: %@", comment: "Download status with detail"), error)
  }
}

/// Vocabolario di rete (connessione, Wi-Fi, VPN) in etichette leggibili.
enum NetworkPresentation {
  static func connectionStateLabel(_ state: String?) -> String {
    switch state {
    case "up": NSLocalizedString("connessa", comment: "Connection state")
    case "down": NSLocalizedString("disconnessa", comment: "Connection state")
    case "going_up": NSLocalizedString("in collegamento", comment: "Connection state")
    case "going_down": NSLocalizedString("in disconnessione", comment: "Connection state")
    default: state ?? "—"
    }
  }

  static func wifiEncryptionLabel(_ raw: String?) -> String {
    guard let raw, !raw.isEmpty else { return "—" }
    let value = raw.lowercased()
    if value.contains("wpa3") { return "WPA3" }
    if value.contains("wpa2") { return "WPA2" }
    if value.contains("wpa") { return "WPA" }
    if value.contains("wep") { return "WEP" }
    if value.contains("open") || value == "none" {
      return NSLocalizedString("Aperta", comment: "Wi-Fi security")
    }
    return raw
  }

  static func wifiBandLabel(_ raw: String?) -> String {
    switch raw?.lowercased() {
    case "2d4g", "2.4g": "2,4 GHz"
    case "5g": "5 GHz"
    case "6g": "6 GHz"
    default: raw ?? "—"
    }
  }

  /// Stato di una rete o di una stazione Wi-Fi.
  static func wifiStateLabel(_ raw: String?) -> String {
    switch raw?.lowercased() {
    case "active", "up": NSLocalizedString("attiva", comment: "Wi-Fi state")
    case "inactive", "down", "disabled": NSLocalizedString("disattiva", comment: "Wi-Fi state")
    case "authorized": NSLocalizedString("connesso", comment: "Wi-Fi station state")
    case "authenticated": NSLocalizedString("autenticato", comment: "Wi-Fi station state")
    default: raw ?? "—"
    }
  }

  static func vpnStateLabel(_ raw: String?, enabled: Bool?) -> String {
    switch raw?.lowercased() {
    case "up", "started", "running", "connected":
      NSLocalizedString("attiva", comment: "VPN state")
    case "down", "stopped", "disconnected":
      NSLocalizedString("disattiva", comment: "VPN state")
    case "error": NSLocalizedString("errore", comment: "VPN state")
    case nil:
      enabled == true
        ? NSLocalizedString("attiva", comment: "VPN state")
        : NSLocalizedString("disattiva", comment: "VPN state")
    default: raw ?? "—"
    }
  }
}
