import Foundation
import CryptoKit

// MARK: - Modelli auth

struct AuthorizeBody: Encodable {
    let app_id: String
    let app_name: String
    let app_version: String
    let device_name: String
}

public struct AuthorizeResult: Decodable, Sendable {
    public let appToken: String
    public let trackId: Int

    enum CodingKeys: String, CodingKey {
        case appToken = "app_token"
        case trackId = "track_id"
    }
}

struct TrackResult: Decodable {
    let status: String // unknown | pending | timeout | granted | denied
}

struct LoginResult: Decodable {
    let loggedIn: Bool
    let challenge: String

    enum CodingKeys: String, CodingKey {
        case loggedIn = "logged_in"
        case challenge
    }
}

struct SessionBody: Encodable {
    let app_id: String
    let app_version: String
    let password: String
}

public struct SessionResult: Decodable, Sendable {
    public let sessionToken: String
    public let permissions: [String: Bool]?

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case permissions
    }
}

// MARK: - Client

/// Client per l'API dell'iliadbox (Freebox OS API).
/// Auth: app_token permanente (pairing con conferma fisica sulla box) +
/// session_token per sessione, ottenuto firmando il challenge con HMAC-SHA1.
public actor IliadboxClient {
    public static let appId = "it.ivansposato.magnetbox"
    public static let appName = "MagnetBox"
    public static let appVersion = "0.1.0"

    private let baseURL: URL
    private var appToken: String?
    private var sessionToken: String?
    private let urlSession: URLSession

    public private(set) var permissions: [String: Bool] = [:]

    public init(config: IbxConfig) {
        // Fallback impossibile in pratica: il default è una costante valida.
        self.baseURL = URL(string: config.baseURL) ?? URL(string: "http://192.168.1.254/api/v15/")!
        self.appToken = config.appToken
        let sc = URLSessionConfiguration.ephemeral
        sc.timeoutIntervalForRequest = 15
        self.urlSession = URLSession(configuration: sc)
    }

    public var isPaired: Bool { appToken != nil }

    // MARK: Pairing

    /// Passo 1: chiede l'autorizzazione. La box mette la richiesta in attesa
    /// di conferma fisica e restituisce subito app_token + track_id.
    public func requestAuthorization(deviceName: String) async throws -> AuthorizeResult {
        let body = AuthorizeBody(
            app_id: Self.appId,
            app_name: Self.appName,
            app_version: Self.appVersion,
            device_name: deviceName
        )
        let result: AuthorizeResult = try await call("login/authorize/", method: "POST", jsonBody: body, authenticated: false)
        appToken = result.appToken
        return result
    }

    /// Passo 2: attende la conferma fisica sulla box (poll ogni 2s).
    /// Ritorna solo quando lo stato è `granted`; lancia su denied/timeout.
    public func waitForApproval(trackId: Int, onPoll: (@Sendable (String) -> Void)? = nil) async throws {
        while true {
            let track: TrackResult = try await call("login/authorize/\(trackId)", method: "GET", authenticated: false)
            onPoll?(track.status)
            switch track.status {
            case "granted":
                return
            case "pending", "unknown":
                try await Task.sleep(nanoseconds: 2_000_000_000)
            default:
                appToken = nil
                throw FbxError.pairingDenied(status: track.status)
            }
        }
    }

    // MARK: Sessione

    /// challenge → HMAC-SHA1(app_token, challenge) in hex → session_token.
    @discardableResult
    public func openSession() async throws -> SessionResult {
        guard let appToken else { throw FbxError.notPaired }

        let login: LoginResult = try await call("login/", method: "GET", authenticated: false)
        let key = SymmetricKey(data: Data(appToken.utf8))
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data(login.challenge.utf8), using: key)
        let password = mac.map { String(format: "%02x", $0) }.joined()

        let body = SessionBody(app_id: Self.appId, app_version: Self.appVersion, password: password)
        let session: SessionResult = try await call("login/session/", method: "POST", jsonBody: body, authenticated: false)
        sessionToken = session.sessionToken
        permissions = session.permissions ?? [:]
        return session
    }

    // MARK: Richieste

    /// Chiamata autenticata, con retry trasparente se la sessione è scaduta.
    func authedCall<T: Decodable>(
        _ path: String,
        method: String = "GET",
        jsonBody: (any Encodable)? = nil,
        formBody: [String: String]? = nil
    ) async throws -> T {
        if sessionToken == nil { try await openSession() }
        do {
            return try await call(path, method: method, jsonBody: jsonBody, formBody: formBody, authenticated: true)
        } catch FbxError.api(let code, _) where code == "auth_required" || code == "invalid_token" {
            sessionToken = nil
            try await openSession()
            return try await call(path, method: method, jsonBody: jsonBody, formBody: formBody, authenticated: true)
        }
    }

    private func call<T: Decodable>(
        _ path: String,
        method: String,
        jsonBody: (any Encodable)? = nil,
        formBody: [String: String]? = nil,
        authenticated: Bool
    ) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.httpMethod = method

        if authenticated, let sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Fbx-App-Auth")
        }
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(jsonBody)
        } else if let formBody {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formEncode(formBody)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FbxError.invalidResponse }

        // La box risponde 403/404 con la stessa busta JSON: proviamo sempre a decodificarla
        // per estrarre error_code/msg prima di ripiegare sul codice HTTP.
        guard let envelope = try? JSONDecoder().decode(FbxResponse<T>.self, from: data) else {
            throw (200...299).contains(http.statusCode) ? FbxError.invalidResponse : FbxError.http(status: http.statusCode)
        }
        guard envelope.success else {
            throw FbxError.api(code: envelope.errorCode, message: envelope.msg)
        }
        if let result = envelope.result { return result }
        // success senza result: valido solo se T lo consente (FbxEmpty o simili).
        if let empty = try? JSONDecoder().decode(T.self, from: Data("{}".utf8)) { return empty }
        throw FbxError.invalidResponse
    }

    /// Percent-encoding rigoroso (solo unreserved RFC 3986): i magnet contengono &, =, :.
    static func formEncode(_ params: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = params
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
            }
            .joined(separator: "&")
        return Data(encoded.utf8)
    }
}
