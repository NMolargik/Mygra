//
//  MenstrualPhase.swift
//  MygraCore
//

import Foundation

nonisolated public enum MenstrualPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case follicular
    case ovulatory
    case luteal
    case menstrual

    public var displayName: String {
        switch self {
        case .menstrual: return String(localized: "Menstrual")
        case .follicular: return String(localized: "Follicular")
        case .ovulatory: return String(localized: "Ovulatory")
        case .luteal: return String(localized: "Luteal")
        }
    }
}
