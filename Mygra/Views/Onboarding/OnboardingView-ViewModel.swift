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
        var currentPage: OnboardingPage = .health
        var newUser: User = User()
        var userFormComplete: Bool = false
        var notificationsAuthorized = false
        var isMovingForward: Bool = true
        
        func criteriaMet(healthManager: HealthManager, weatherManager: WeatherManager) -> Bool {
            switch(self.currentPage) {
            case .health:
                return healthManager.isAuthorized
            case .location:
                return weatherManager.locationManager?.isAuthorized ?? false
            case .notifications:
                return true
            case .user:
                return userFormComplete
            case .complete:
                return true
            }
        }
        
        var forwardTransition: AnyTransition {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
        
        var backwardTransition: AnyTransition {
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                // when going back: outgoing page exits toward trailing
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
}
