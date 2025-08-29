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
    }
}
