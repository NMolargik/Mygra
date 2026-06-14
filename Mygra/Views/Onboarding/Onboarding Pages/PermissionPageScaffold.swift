//
//  PermissionPageScaffold.swift
//  Mygra
//
//  Created by Nick Molargik on 6/12/26.
//

import SwiftUI
import UIKit

/// The authorization state of a system permission as presented on an onboarding page.
enum PermissionState: Equatable {
    case notRequested
    case granted
    case denied
}

/// Shared layout for the onboarding permission pages (Health, Location, Notifications).
///
/// Renders a large tinted status icon, title, description, a status indicator,
/// an optional feature-bullet list, and an action button whose label and behavior
/// follow `state`:
/// - `.notRequested`: shows the request button and invokes `onRequest`
/// - `.denied`: shows an "Open Settings" button that deep-links into Settings
/// - `.granted`: hides the button entirely
///
/// The scaffold also plays a success haptic whenever `state` transitions to `.granted`.
struct PermissionPageScaffold<Content: View>: View {
    private let state: PermissionState
    private let icon: String
    private let iconColor: Color
    private let title: String
    private let description: String
    private let requestButtonTitle: String
    private let requestButtonIcon: String
    private let requestButtonColor: Color
    private let isRequestEnabled: Bool
    private let onRequest: () -> Void
    private let features: Content?

    init(
        state: PermissionState,
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        requestButtonTitle: String,
        requestButtonIcon: String,
        requestButtonColor: Color = .mygraBlue,
        isRequestEnabled: Bool = true,
        onRequest: @escaping () -> Void,
        @ContentBuilder features: () -> Content
    ) {
        self.state = state
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.requestButtonTitle = requestButtonTitle
        self.requestButtonIcon = requestButtonIcon
        self.requestButtonColor = requestButtonColor
        self.isRequestEnabled = isRequestEnabled
        self.onRequest = onRequest
        self.features = features()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                if let features {
                    VStack(spacing: 0) {
                        features
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                }

                actionButton

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onChange(of: state) { _, newValue in
            if newValue == .granted {
                Haptics.success()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(iconColor)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            Text(title)
                .font(.title.bold())

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            statusIndicator
        }
        .padding(.top, 24)
    }

    // MARK: - Status Indicator

    private var statusText: String {
        switch state {
        case .notRequested: return "Not yet requested"
        case .granted: return "Access granted"
        case .denied: return "Access denied"
        }
    }

    private var statusColor: Color {
        switch state {
        case .notRequested: return .secondary
        case .granted: return .green
        case .denied: return .orange
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Permission status: \(statusText)")
    }

    // MARK: - Action Button

    @ContentBuilder
    private var actionButton: some View {
        switch state {
        case .notRequested:
            Button {
                Haptics.mediumImpact()
                onRequest()
            } label: {
                Label(requestButtonTitle, systemImage: requestButtonIcon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(requestButtonColor.opacity(isRequestEnabled ? 1 : 0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isRequestEnabled)
            .frame(maxWidth: 500)
            .padding(.horizontal, 20)
            .accessibilityLabel(requestButtonTitle)
            .accessibilityHint(isRequestEnabled
                ? "Shows the system permission prompt."
                : "This permission can't be requested right now.")
        case .denied:
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
            .accessibilityLabel("Open Settings")
            .accessibilityHint("Opens the Settings app where you can grant access.")
        case .granted:
            EmptyView()
        }
    }
}

// MARK: - Convenience init (no feature list)

extension PermissionPageScaffold where Content == EmptyView {
    init(
        state: PermissionState,
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        requestButtonTitle: String,
        requestButtonIcon: String,
        requestButtonColor: Color = .mygraBlue,
        isRequestEnabled: Bool = true,
        onRequest: @escaping () -> Void
    ) {
        self.state = state
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.requestButtonTitle = requestButtonTitle
        self.requestButtonIcon = requestButtonIcon
        self.requestButtonColor = requestButtonColor
        self.isRequestEnabled = isRequestEnabled
        self.onRequest = onRequest
        self.features = nil
    }
}

// MARK: - Feature Row

/// A single feature bullet shown inside a permission page's feature card.
/// Replaces the per-page `FeatureRow` copies.
struct PermissionFeatureRow: View {
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
    PermissionPageScaffold(
        state: .notRequested,
        icon: "bell.circle.fill",
        iconColor: .mygraBlue,
        title: "Enable Notifications",
        description: "Allow notifications to get weather alerts and migraine reminders.",
        requestButtonTitle: "Allow Notifications",
        requestButtonIcon: "bell.fill",
        onRequest: {}
    ) {
        PermissionFeatureRow(
            icon: "cloud.sun.fill",
            iconColor: .orange,
            title: "Weather Alerts",
            description: "Get notified about conditions that may trigger migraines."
        )
    }
}
