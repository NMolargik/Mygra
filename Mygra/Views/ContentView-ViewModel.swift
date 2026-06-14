//
//  ContentView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

extension ContentView {
    @Observable
    final class ViewModel {
        // MARK: - App State
        var appStage: AppStage = .splash

        // MARK: - Transitions
        var leadingTransition: AnyTransition {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }

        func prepareApp(isOnboardingComplete: Bool) {
            // Returning users go straight to the app; iCloud sync runs in the
            // background and surfaces through a toast rather than a blocking screen.
            appStage = isOnboardingComplete ? .main : .splash
        }
    }
}

