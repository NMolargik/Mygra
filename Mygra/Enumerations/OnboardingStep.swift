//
//  OnboardingStep.swift
//  Mygra
//
//  Created by Nick Molargik on 1/20/26.
//

import Foundation

enum OnboardingStep: CaseIterable {
    case privacy
    case location
    case health
    case notification
    case user
    case complete

    var title: String {
        switch self {
        case .privacy: return "Your Privacy"
        case .location: return "Location"
        case .health: return "Step Count"
        case .notification: return "Notifications"
        case .user: return "About You"
        case .complete: return "You're All Set"
        }
    }
}
