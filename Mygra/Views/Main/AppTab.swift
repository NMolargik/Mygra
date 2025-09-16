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

    func icon() -> Image {
        switch self {
        case .insights:
            return Image(systemName: "lightbulb.max.fill")
        case .list:
            return Image(systemName: "list.bullet.indent")
        case .settings:
            return Image(systemName: "gearshape.2")
        }
    }
}
