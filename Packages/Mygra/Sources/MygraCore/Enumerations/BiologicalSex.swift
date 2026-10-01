//
//  BiologicalSex.swift
//  MygraCore
//

import Foundation

nonisolated public enum BiologicalSex: String, Codable, CaseIterable, Sendable {
    case female
    case male

    public var displayName: String {
        switch self {
        case .female: return String(localized: "Female")
        case .male: return String(localized: "Male")
        }
    }
}
