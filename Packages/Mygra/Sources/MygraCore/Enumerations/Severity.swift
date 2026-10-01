//
//  Severity.swift
//  MygraCore
//
//  Pain-level bucket. Color styling lives in MygraDesignSystem.
//

import Foundation

nonisolated public enum Severity: String, Codable, CaseIterable, Sendable {
    case low, medium, high

    /// The bucket a 0–10 pain level falls into.
    public static func from(painLevel: Int) -> Severity {
        switch painLevel {
        case ..<4: return .low      // 0–3
        case 4...6: return .medium  // 4–6
        default: return .high       // 7–10
        }
    }

    public var displayName: String {
        switch self {
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        }
    }

    /// e.g. "High (8)".
    public func text(for painLevel: Int) -> String {
        "\(displayName) (\(painLevel))"
    }
}
