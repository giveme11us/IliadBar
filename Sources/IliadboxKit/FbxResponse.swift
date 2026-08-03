import Foundation

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
            return "Errore API iliadbox: \(message ?? "sconosciuto") [\(code ?? "-")]"
        case .http(let status):
            return "Errore HTTP \(status)"
        case .notPaired:
            return "Non associato alla iliadbox: esegui prima `ibx pair`"
        case .pairingDenied(let status):
            return "Associazione non concessa (stato: \(status))"
        case .invalidResponse:
            return "Risposta non valida dalla iliadbox"
        }
    }
}
