import Foundation

public enum IliadboxInputValidator {
  public static func isIPv4Address(_ value: String) -> Bool {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return false }
    return parts.allSatisfy { part in
      guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber), let octet = Int(part)
      else { return false }
      return (0...255).contains(octet)
    }
  }

  public static func isMACAddress(_ value: String) -> Bool {
    let normalized = value.replacingOccurrences(of: "-", with: ":")
    let parts = normalized.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 6 else { return false }
    return parts.allSatisfy { part in
      part.count == 2 && part.allSatisfy { $0.isHexDigit }
    }
  }

  public static func isSupportedAPIURL(_ value: String) -> Bool {
    guard let components = URLComponents(string: value),
      let scheme = components.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      components.host?.isEmpty == false,
      components.user == nil,
      components.password == nil
    else { return false }
    return true
  }
}
