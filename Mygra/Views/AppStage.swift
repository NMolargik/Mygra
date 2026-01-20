//
//  AppStage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import Foundation

enum AppStage: String, Identifiable {
    case splash
    case onboarding
    case syncing     // iCloud data check with timeout
    case main

    var id: String { self.rawValue }
}
