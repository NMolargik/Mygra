//
//  OnboardingView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

extension OnboardingView {
    @Observable
    final class ViewModel {
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

        /// The step after `currentStep` in `OnboardingStep.allCases`, or nil when on the last step.
        private var nextStep: OnboardingStep? {
            let steps = OnboardingStep.allCases
            guard let index = steps.firstIndex(of: currentStep),
                  steps.index(after: index) < steps.endIndex else {
                return nil
            }
            return steps[steps.index(after: index)]
        }

        func handleContinueTapped() {
            guard let nextStep else { return }
            currentStep = nextStep
        }

        func handleSkipTapped() {
            guard showsSkip, let nextStep else { return }
            currentStep = nextStep
        }
    }
}
