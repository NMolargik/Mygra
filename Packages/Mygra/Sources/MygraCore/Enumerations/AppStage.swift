//
//  AppStage.swift
//  MygraCore
//

import Foundation

nonisolated public enum AppStage: String, Identifiable, Sendable {
    case splash      // Animated branding, "Get Started" button
    case onboarding  // Privacy, Location, Health, Notifications, About You, Complete
    case main        // Main app experience (iCloud sync runs in the background)

    public var id: String { rawValue }
}
