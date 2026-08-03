import Foundation

private func fbxLocalized(_ key: String, _ arguments: CVarArg...) -> String {
  String(format: NSLocalizedString(key, comment: "iliadbox API error"), arguments: arguments)
}

/// Busta standard di ogni risposta dell'API Freebox/iliadbox:
/// { "success": bool, "result": T?, "msg": "...", "error_code": "..." }
public struct FbxResponse<T: Decodable>: Decodable {
  public let success: Bool
  public let result: T?
  public let msg: String?
  public let errorCode: String?

  enum CodingKeys: String, CodingKey {
    case success, result, msg
    case errorCode = "error_code"
  }
}

/// Placeholder per endpoint che non restituiscono un result utile.
public struct FbxEmpty: Decodable {}

public enum FbxError: Error, LocalizedError {
  case api(code: String?, message: String?)
  case http(status: Int)
  case notPaired
  case pairingDenied(status: String)
  case invalidResponse

  public var errorDescription: String? {
    switch self {
    case .api(let code, let message):
      return fbxLocalized(
        "Errore API iliadbox: %@ [%@]",
        message ?? fbxLocalized("sconosciuto"),
        code ?? "-"
      )
    case .http(let status):
      return fbxLocalized("Errore HTTP %@", status)
    case .notPaired:
      return fbxLocalized("Non associato alla iliadbox: completa prima l’associazione")
    case .pairingDenied(let status):
      return fbxLocalized("Associazione non concessa (stato: %@)", status)
    case .invalidResponse:
      return fbxLocalized("Risposta non valida dalla iliadbox")
    }
  }
}

public enum FbxFailureCategory: String, Sendable {
  case authentication
  case permission
  case transport
  case server
  case invalidData
}

extension FbxError {
  public var category: FbxFailureCategory {
    switch self {
    case .notPaired, .pairingDenied:
      return .authentication
    case .api(let code, _):
      if code == "insufficient_rights" { return .permission }
      if ["auth_required", "invalid_token", "pending_token"].contains(code ?? "") {
        return .authentication
      }
      return .server
    case .http:
      return .transport
    case .invalidResponse:
      return .invalidData
    }
  }
}
