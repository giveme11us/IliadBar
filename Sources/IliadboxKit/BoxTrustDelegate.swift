import CryptoKit
import Foundation
import OSLog
import Security

/// Validates ordinary public certificates first. Iliadbox currently serves a
/// valid host certificate whose private CA is not in the macOS trust store, so
/// the fallback anchors trust to the known Iliadbox intermediate certificate.
/// Hostname, validity dates, and the cryptographic chain are still evaluated by
/// Security.framework; this is not an accept-all TLS delegate.
final class BoxTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
  private static let logger = Logger(subsystem: "it.ivansposato.iliadbar", category: "TLS")
  // Subject: Iliadbox ECC Intermediate CA, issuer: Iliadbox ECC Root CA.
  // Observed through the box chain and pinned as certificate DER SHA-256.
  private static let pinnedAnchorSHA256: Set<String> = [
    "6af76766fd7d39fbdba48233e60f75880e08ba5115686a8eef867daa6c21a6f3"
  ]

  private let expectedHost: String?

  init(expectedHost: String?) {
    self.expectedHost = expectedHost?.lowercased()
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let trust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    let host = challenge.protectionSpace.host.lowercased()
    guard expectedHost == nil || expectedHost == host else {
      Self.logger.error("TLS challenge rejected: unexpected host")
      Self.debugLog("IbxTLS: reject host \(host) (atteso \(expectedHost ?? "-"))")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    var defaultError: CFError?
    if SecTrustEvaluateWithError(trust, &defaultError) {
      completionHandler(.useCredential, URLCredential(trust: trust))
      return
    }
    #if DEBUG
      Self.debugLog(
        "IbxTLS: default eval fallita per \(host): \(defaultError.map(String.init(describing:)) ?? "-")"
      )
      Self.debugLog(Self.chainDescription(trust))
    #endif

    guard let anchor = Self.pinnedAnchor(in: trust) else {
      Self.logger.error("TLS challenge rejected: pinned anchor missing")
      Self.debugLog("IbxTLS: anchor pinmato assente nella chain servita")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    // Verifica crittografica su una copia: la leaf deve essere davvero firmata
    // dalla CA intermedia pinmata (hash uguale non basta, il certificato è
    // materiale pubblico). La copia evita di consepire a URLSession un trust
    // modificato: iOS 26 rifiuta con -1200 le credential costruite da trust
    // ri-ancorati, mentre onora il classico schema del pinning.
    let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
    var verificationTrust: SecTrust?
    let status = SecTrustCreateWithCertificates(
      chain as CFArray,
      SecPolicyCreateSSL(true, host as CFString),
      &verificationTrust
    )
    guard status == errSecSuccess, let verificationTrust else {
      Self.logger.error("TLS challenge rejected: verification trust unavailable")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }
    SecTrustSetAnchorCertificates(verificationTrust, [anchor] as CFArray)
    SecTrustSetAnchorCertificatesOnly(verificationTrust, true)
    var pinnedError: CFError?
    guard SecTrustEvaluateWithError(verificationTrust, &pinnedError) else {
      Self.logger.error("TLS challenge rejected after pinned evaluation")
      Self.debugLog(
        "IbxTLS: pinned eval fallita: \(pinnedError.map(String.init(describing:)) ?? "-")")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }
    Self.logger.debug("TLS challenge accepted with pinned anchor")
    Self.debugLog("IbxTLS: accettata con anchor pinmato (trust originale)")
    completionHandler(.useCredential, URLCredential(trust: trust))
  }

  #if DEBUG
    private static func debugLog(_ message: String) {
      NSLog("%@", message)
    }

    private static func chainDescription(_ trust: SecTrust) -> String {
      guard let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate]
      else { return "IbxTLS: chain non disponibile" }
      return certificates.enumerated().map { index, certificate in
        let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? "?"
        let digest = SHA256.hash(data: SecCertificateCopyData(certificate) as Data)
          .prefix(8).map { String(format: "%02x", $0) }.joined()
        return "IbxTLS: [\(index)] \(summary) sha256:\(digest)…"
      }.joined(separator: "\n")
    }
  #else
    private static func debugLog(_ message: String) {}
  #endif

  private static func pinnedAnchor(in trust: SecTrust) -> SecCertificate? {
    guard let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
      return nil
    }
    for certificate in certificates {
      let data = SecCertificateCopyData(certificate) as Data
      let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
      if pinnedAnchorSHA256.contains(digest) { return certificate }
    }
    return nil
  }
}
