//
//  AppTab.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case calendar = "Calendar"
    case list = "Migraines"
    case settings = "Settings"

    var id: String { self.rawValue }

    func icon() -> Image {
        switch self {
        case .dashboard:
            return Image(systemName: "square.grid.2x2.fill")
        case .calendar:
            return Image(systemName: "calendar")
        case .list:
            return Image(systemName: "list.bullet")
        case .settings:
            return Image(systemName: "gearshape.2")
        }
    }

    func color() -> Color {
        switch self {
        case .dashboard:
            return Color.pink
        case .calendar:
            return Color.mygraPurple
        case .list:
            return Color.mygraBlue
        case .settings:
            return Color.orange
        }
    }
}
