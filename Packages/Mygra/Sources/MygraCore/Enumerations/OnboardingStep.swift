//
//  OnboardingStep.swift
//  MygraCore
//
//  The onboarding pages in order. Navigation rules (skippable, gating) live here so
//  the flow is host-testable without SwiftUI.
//

import Foundation

nonisolated public enum OnboardingStep: CaseIterable, Sendable, Hashable {
    case privacy
    case location
    case health
    case notification
    case user
    case complete

    public var title: String {
        switch self {
        case .privacy: return String(localized: "Your Privacy")
        case .location: return String(localized: "Location")
        case .health: return String(localized: "Health")
        case .notification: return String(localized: "Notifications")
        case .user: return String(localized: "About You")
        case .complete: return String(localized: "You're All Set")
        }
    }

    /// Steps the user may skip without granting anything.
    public var isSkippable: Bool {
        switch self {
        case .privacy, .location, .notification: return true
        case .health, .user, .complete: return false
        }
    }

    /// The step after this one, or nil on the last step.
    public var next: OnboardingStep? {
        let steps = Self.allCases
        guard let index = steps.firstIndex(of: self), steps.index(after: index) < steps.endIndex else {
            return nil
        }
        return steps[steps.index(after: index)]
    }
}
