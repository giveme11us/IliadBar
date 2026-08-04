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
