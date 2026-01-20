//
//  OnboardingView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

extension OnboardingView {
    @Observable
    class ViewModel {
        var currentStep: OnboardingStep = .privacy
        var newUser: User = User()
        var userFormComplete: Bool = false
        
        var canContinue: Bool {
            switch currentStep {
            case .privacy, .location, .health, .notification, .complete:
                return true
            case .user:
                return userFormComplete
            }
        }

        var showsSkip: Bool {
            switch currentStep {
            case .location, .notification, .privacy:
                return true
            case .complete, .health, .user:
                return false
            }
        }
        
        func handleContinueTapped() {
            switch currentStep {
            case .privacy:
                currentStep = .health
            case .health:
                currentStep = .location
            case .location:
                currentStep = .notification
            case .notification:
                currentStep = .user
            case .user:
                currentStep = .complete
            case .complete:
                break
            }
        }
        
        func handleSkipTapped() {
            switch currentStep {
            case .privacy:
                currentStep = .health
            case .health:
                break
            case .location:
                currentStep = .notification
            case .notification:
                currentStep = .user
            case .user:
                break
            case .complete:
                break
            }
        }
    }
}
