//
//  AppTab.swift
//  MygraCore
//
//  The four main tabs. Icon/color styling lives in MygraDesignSystem.
//

import Foundation

nonisolated public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard = "Dashboard"
    case calendar = "Calendar"
    case list = "Migraines"
    case settings = "Settings"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return String(localized: "Dashboard")
        case .calendar: return String(localized: "Calendar")
        case .list: return String(localized: "Migraines")
        case .settings: return String(localized: "Settings")
        }
    }
}
