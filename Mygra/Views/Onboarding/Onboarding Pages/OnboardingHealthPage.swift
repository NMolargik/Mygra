//
//  OnboardingHealthPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingHealthPage: View {
    @Environment(HealthManager.self) var healthManager: HealthManager
    
    private var statusConfig: (icon: String, color: Color, title: String, description: String) {
        if healthManager.isAuthorized {
            return (
                "checkmark.circle.fill",
                .green,
                "Health Connected",
                "We'll collect your health information for migraine context."
            )
        } else if healthManager.lastError != nil {
            return (
                "heart.slash.fill",
                .orange,
                "Access Denied",
                "Enable Health access in Settings to collect health information for migraine context."
            )
        } else {
            return (
                "heart.fill",
                .pink,
                "Connect Health",
                "Allow access to Health to collect health information for migraine context."
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

                // Action Button
                if !healthManager.isAuthorized {
                    if healthManager.lastError != nil {
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
                    } else {
                        Button {
                            Haptics.mediumImpact()
                            Task {
                                await healthManager.requestAuthorization()
                            }
                        } label: {
                            Label("Connect Apple Health", systemImage: "heart.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.pink)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .frame(maxWidth: 500)
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

private struct HealthFeatureRow: View {
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
    OnboardingHealthPage()
        .environment(HealthManager())
}
