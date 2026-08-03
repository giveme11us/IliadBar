import Foundation
import LocalAuthentication
import Security

public enum KeychainTokenError: Error, LocalizedError, Sendable {
  case unexpectedStatus(OSStatus)
  case invalidData

  public var errorDescription: String? {
    switch self {
    case .unexpectedStatus(let status):
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
      return "Keychain: \(message)"
    case .invalidData:
      return "Il token salvato nel Portachiavi non è valido"
    }
  }
}

/// Stores one Freebox app token per profile. Tokens never need to be exposed to
/// the UI and are intentionally excluded from the JSON configuration.
public enum KeychainTokenStore {
  public static var service: String {
    ProcessInfo.processInfo.environment["ILIADBAR_KEYCHAIN_SERVICE"]
      ?? "it.ivansposato.iliadbar.app-token"
  }

  public static func read(profileID: String, allowInteraction: Bool = true) throws -> String? {
    var query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: profileID,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    if !allowInteraction {
      let context = LAContext()
      context.interactionNotAllowed = true
      query[kSecUseAuthenticationContext] = context
    }
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeychainTokenError.unexpectedStatus(status) }
    guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
      throw KeychainTokenError.invalidData
    }
    return token
  }

  public static func save(_ token: String, profileID: String) throws {
    let identity: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: profileID,
    ]
    let attributes: [CFString: Any] = [
      kSecValueData: Data(token.utf8),
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
    ]

    let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw KeychainTokenError.unexpectedStatus(updateStatus)
    }

    var item = identity
    attributes.forEach { item[$0.key] = $0.value }
    let addStatus = SecItemAdd(item as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw KeychainTokenError.unexpectedStatus(addStatus) }
  }

  public static func delete(profileID: String) throws {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: profileID,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainTokenError.unexpectedStatus(status)
    }
  }
}
