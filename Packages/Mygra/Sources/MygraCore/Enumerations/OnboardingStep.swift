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

    /// The SF Symbol that represents this step (progress indicators, headers).
    public var systemImage: String {
        switch self {
        case .privacy: return "lock.shield.fill"
        case .location: return "location.fill"
        case .health: return "heart.fill"
        case .notification: return "bell.fill"
        case .user: return "person.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }

    /// Steps that ask for a system permission. Per the HIG these are never required:
    /// the user may skip any of them and grant access later from Settings.
    public var isPermissionStep: Bool {
        switch self {
        case .location, .health, .notification: return true
        case .privacy, .user, .complete: return false
        }
    }

    /// Steps the user may skip without granting or entering anything.
    public var isSkippable: Bool {
        switch self {
        case .privacy, .location, .health, .notification, .user: return true
        case .complete: return false
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

    /// The step before this one, or nil on the first step.
    public var previous: OnboardingStep? {
        let steps = Self.allCases
        guard let index = steps.firstIndex(of: self), index > steps.startIndex else { return nil }
        return steps[steps.index(before: index)]
    }
}
