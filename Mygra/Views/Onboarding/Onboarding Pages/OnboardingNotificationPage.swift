//
//  OnboardingNotificationPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import UserNotifications

struct OnboardingNotificationPage: View {
    @Environment(NotificationManager.self) private var notificationManager

    private var state: PermissionState {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notRequested
        @unknown default:
            return .notRequested
        }
    }

    private var statusConfig: (icon: String, color: Color, title: String, description: String) {
        switch state {
        case .granted:
            return (
                "checkmark.circle.fill",
                .green,
                "Notifications Enabled",
                "You'll receive alerts about weather and migraine reminders."
            )
        case .denied:
            return (
                "bell.slash.fill",
                .orange,
                "Notifications Disabled",
                "Enable notifications in Settings to receive alerts."
            )
        case .notRequested:
            return (
                "bell.circle.fill",
                .mygraBlue,
                "Enable Notifications",
                "Allow notifications to get weather alerts and migraine reminders."
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
            requestButtonTitle: "Allow Notifications",
            requestButtonIcon: "bell.fill",
            requestButtonColor: .mygraBlue,
            onRequest: {
                Task {
                    try? await notificationManager.requestAuthorization()
                }
            }
        ) {
            PermissionFeatureRow(
                icon: "cloud.sun.fill",
                iconColor: .orange,
                title: "Weather Alerts",
                description: "Get notified about conditions that may trigger migraines."
            )
        }
    }
}

#Preview {
    OnboardingNotificationPage()
        .environment(NotificationManager())
}
