//
//  InsightPriority.swift
//  MygraCore
//

import Foundation

nonisolated public enum InsightPriority: Int, Comparable, Hashable, Sendable, CaseIterable {
    case low = 1
    case medium = 5
    case high = 9

    public static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .high: return String(localized: "High")
        case .medium: return String(localized: "Medium")
        case .low: return String(localized: "Low")
        }
    }
}
