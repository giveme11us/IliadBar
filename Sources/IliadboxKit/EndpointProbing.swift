import Foundation

/// Negoazione dell'endpoint raggiungibile per una box.
///
/// La box annuncia via Bonjour un dominio DDNS (`api_domain`) che dalla LAN
/// risolve all'indirizzo pubblico e serve HTTPS su una porta dedicata con una
/// catena di certificati priva di root: macOS la accetta ancorando la CA
/// intermedia pinmata, iOS no — URLSession rifiuta con `-1200` ogni
/// credential la cui catena non raggiunge una root. L'API della box però è
/// servita identica in HTTP chiaro sul suo indirizzo LAN (il canale storico
/// Freebox OS), quindi su iOS si cerca l'endpoint HTTP vivo tra i candidati.
public enum IliadboxEndpointProber {
  /// Candidati in ordine di preferenza per il trasporto HTTP su LAN.
  public static func httpCandidates(for baseURL: URL) -> [URL] {
    // URL.path droppa lo slash finale: la base per il client deve chiudere
    // con "/", altrimenti ogni concatenazione di endpoint produce 404.
    var path = baseURL.path
    if !path.hasSuffix("/") { path += "/" }
    var candidates: [URL] = []
    func append(host: String) {
      var components = URLComponents()
      components.scheme = "http"
      components.host = host
      components.path = path
      if let url = components.url, !candidates.contains(url) {
        candidates.append(url)
      }
    }
    // Indirizzo LAN tipico dei gateway iliadbox/Freebox OS.
    append(host: "192.168.1.254")
    // Su alcune reti il nome annunciato è raggiungibile anche in chiaro.
    if let host = baseURL.host { append(host: host) }
    return candidates
  }

  /// Primo endpoint che risponde con la firma dell'API. `system/` non
  /// richiede autenticazione: una base URL con la versione giusta risponde
  /// sempre con uid e challenge della box.
  public static func firstReachableHTTPBase(for baseURL: URL) async -> URL? {
    for candidate in httpCandidates(for: baseURL) {
      guard var components = URLComponents(url: candidate, resolvingAgainstBaseURL: false)
      else { continue }
      components.path = candidate.path + "system/"
      if !candidate.path.hasSuffix("/") {
        components.path = candidate.path + "/system/"
      }
      guard let probeURL = components.url else { continue }
      var request = URLRequest(url: probeURL)
      request.timeoutInterval = 5
      do {
        let (data, _) = try await URLSession.shared.data(for: request)
        // La box risponde 403 alle chiamate non autenticate: lo status non è
        // discriminante, la firma JSON (uid + result/challenge) sì.
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          body["uid"] is String,
          body["result"] is [String: Any]
        {
          return candidate
        }
        Self.probeLog("\(probeURL): raggiungibile ma senza firma API")
        continue
      } catch {
        let ns = error as NSError
        Self.probeLog("\(probeURL): \(ns.domain) \(ns.code) — \(ns.localizedDescription)")
        continue
      }
    }
    return nil
  }

  private static func probeLog(_ message: String) {
    #if DEBUG
      NSLog("IbxProbe: %@", message)
    #endif
  }
}
