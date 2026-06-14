//
//  OnboardingHealthPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingHealthPage: View {
    @Environment(HealthManager.self) var healthManager: HealthManager

    private var state: PermissionState {
        if healthManager.isAuthorized {
            return .granted
        } else if healthManager.lastError != nil {
            return .denied
        } else {
            return .notRequested
        }
    }

    private var statusConfig: (icon: String, color: Color, title: String, description: String) {
        switch state {
        case .granted:
            return (
                "checkmark.circle.fill",
                .green,
                "Health Connected",
                "We'll collect your health information for migraine context."
            )
        case .denied:
            return (
                "heart.slash.fill",
                .orange,
                "Access Denied",
                "Enable Health access in Settings to collect health information for migraine context."
            )
        case .notRequested:
            return (
                "heart.fill",
                .pink,
                "Connect Health",
                "Allow access to Health to collect health information for migraine context."
            )
        }
    }

    var body: some View {
        PermissionPageScaffold(
            state: state,
            icon: statusConfig.icon,
            iconColor: statusConfig.color,
            title: statusConfig.title,
            description: statusConfig.description,
            requestButtonTitle: "Connect Apple Health",
            requestButtonIcon: "heart.fill",
            requestButtonColor: .pink,
            onRequest: {
                Task {
                    await healthManager.requestAuthorization()
                }
            }
        )
    }
}

#Preview {
    OnboardingHealthPage()
        .environment(HealthManager())
}
