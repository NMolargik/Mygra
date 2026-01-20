//
//  OnboardingPrivacyPage.swift
//  Mygra
//
//  Created by Nick Molargik on 1/20/26.
//

import SwiftUI

struct OnboardingPrivacyPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.mygraPurple)
                        .accessibilityHidden(true)

                    Text("Your Privacy Matters")
                        .font(.title.bold())

                    Text("Mygra is designed to keep your data private and secure.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                // Privacy Features
                VStack(spacing: 0) {
                    PrivacyRow(
                        icon: "iphone",
                        iconColor: .mygraBlue,
                        title: "On-Device Storage",
                        description: "Your migraine data stays on your device and in your personal iCloud."
                    )

                    Divider().padding(.leading, 56)

                    PrivacyRow(
                        icon: "person.fill.checkmark",
                        iconColor: .mygraPurple,
                        title: "Your Data, Your Control",
                        description: "Only you can access your migraine history and health insights."
                    )

                    Divider().padding(.leading, 56)

                    PrivacyRow(
                        icon: "server.rack",
                        iconColor: .mygraBlue,
                        title: "No External Servers",
                        description: "We never send your health data to third-party servers."
                    )

                    Divider().padding(.leading, 56)

                    PrivacyRow(
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        title: "End-to-End Encrypted",
                        description: "iCloud data is encrypted and only accessible by you."
                    )
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PrivacyRow: View {
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
    OnboardingPrivacyPage()
}
