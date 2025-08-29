//
//  AppStage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import Foundation

enum AppStage: String, Identifiable {
    case start
    case splash
    case onboarding
    case main
    
    var id: String { self.rawValue }
}
