//
//  OnboardingNotificationPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import UserNotifications
import UIKit

struct OnboardingNotificationPage: View {
    @Environment(NotificationManager.self) private var notificationManager

    private var status: UNAuthorizationStatus { notificationManager.authorizationStatus }

    private var statusConfig: (icon: String, color: Color, title: String, description: String) {
        switch status {
        case .authorized, .provisional, .ephemeral:
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
        case .notDetermined:
            return (
                "bell.circle.fill",
                .mygraBlue,
                "Enable Notifications",
                "Allow notifications to get weather alerts and migraine reminders."
            )
        @unknown default:
            return (
                "questionmark.circle.fill",
                .secondary,
                "Unknown Status",
                "We couldn't determine your notification settings."
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: statusConfig.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(statusConfig.color)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)

                    Text(statusConfig.title)
                        .font(.title.bold())

                    Text(statusConfig.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                // Features
                VStack(spacing: 0) {
                    FeatureRow(
                        icon: "cloud.sun.fill",
                        iconColor: .orange,
                        title: "Weather Alerts",
                        description: "Get notified about conditions that may trigger migraines."
                    )
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)

                // Action Button
                if status == .notDetermined {
                    Button {
                        Haptics.mediumImpact()
                        Task {
                            try? await notificationManager.requestAuthorization()
                        }
                    } label: {
                        Label("Allow Notifications", systemImage: "bell.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.mygraBlue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                } else if status == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingNotificationPage()
        .environment(NotificationManager())
}
