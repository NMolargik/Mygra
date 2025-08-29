//
//  AppTab.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case insights = "Insights"
    case list = "Migraines"
    case settings = "Settings"
    
    var id: String { self.rawValue }

    // Icon that depends on whether this tab is selected
    func icon(selectedTab: AppTab) -> Image {
        let isSelected = (self == selectedTab)
        switch self {
        case .insights:
            // Selected: lightbulb.max.fill, Unselected: lightbulb
            return Image(systemName: isSelected ? "lightbulb.max.fill" : "lightbulb.min.fill")
        case .list:
            // Selected: list.dash (existing), Unselected: list.bullet.indent (requested)
            return Image(systemName: isSelected ? "list.bullet" : "list.bullet.indent")
        case .settings:
            // Selected: gearshape (existing), Unselected: gearshape.2 (requested)
            return Image(systemName: isSelected ? "gearshape" : "gearshape.2")
        }
    }
    
    var color: Color {
        switch self {
        case .insights: return Color.orange
        case .list: return Color.indigo
        case .settings: return Color.green
        }
    }
}
