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

    /// The SF Symbol shown in the tab bar / sidebar.
    public var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .calendar: return "calendar"
        case .list: return "list.bullet"
        case .settings: return "gearshape.2"
        }
    }

    /// The ⌘-number shortcut that selects this tab (menu bar / hardware keyboard).
    public var keyboardNumber: Int {
        switch self {
        case .dashboard: return 1
        case .calendar: return 2
        case .list: return 3
        case .settings: return 4
        }
    }
}
