import Foundation

/// Presentation only. Stored effort and legacy shared snapshots remain on the 0–100 axis.
public enum PersonalScoreDisplay {
    public static let policyVersion = 1
    public static func effortValue(stored: Double?) -> Double? {
        guard let stored, stored.isFinite, (0...100).contains(stored) else { return nil }
        return stored * (21.0 / 100.0)
    }

    public static func effortText(stored: Double?) -> String? {
        effortValue(stored: stored).map { String(format: "%.1f", $0) }
    }
}
