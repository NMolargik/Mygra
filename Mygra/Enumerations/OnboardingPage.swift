//
//  OnboardingPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation

enum OnboardingPage {
    case health
    case location
    case notifications
    case user
    case complete
    
    var next: OnboardingPage {
        switch self {
        case .health: return .location
        case .location: return .notifications
        case .notifications: return .user
        case .user: return .complete
        case .complete: return .complete
        }
    }
    var previous: OnboardingPage {
        switch self {
        case .health: return .health
        case .location: return .health
        case .notifications: return .location
        case .user: return .notifications
        case .complete: return .user
        }
    }
}
