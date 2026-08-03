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
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    var defaultError: CFError?
    if SecTrustEvaluateWithError(trust, &defaultError) {
      completionHandler(.useCredential, URLCredential(trust: trust))
      return
    }

    guard let anchor = Self.pinnedAnchor(in: trust) else {
      Self.logger.error("TLS challenge rejected: pinned anchor missing")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString))
    SecTrustSetAnchorCertificates(trust, [anchor] as CFArray)
    SecTrustSetAnchorCertificatesOnly(trust, true)
    var pinnedError: CFError?
    guard SecTrustEvaluateWithError(trust, &pinnedError) else {
      Self.logger.error("TLS challenge rejected after pinned evaluation")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }
    Self.logger.debug("TLS challenge accepted with pinned anchor")
    completionHandler(.useCredential, URLCredential(trust: trust))
  }

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
