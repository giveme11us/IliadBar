import Foundation

public enum AutomationJSON {
  public static func data(_ value: Any) throws -> Data {
    try JSONSerialization.data(
      withJSONObject: value,
      options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
  }
}
