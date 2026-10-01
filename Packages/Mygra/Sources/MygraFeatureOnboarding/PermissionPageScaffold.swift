//
//  PermissionPageScaffold.swift
//  MygraFeatureOnboarding
//
//  Shared layout for the permission pages (Health, Location, Notifications): a large
//  tinted status icon, title, description, status indicator, optional feature list, and
//  an action button whose behavior follows `state`.
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

/// The authorization state of a system permission as presented on an onboarding page.
enum PermissionState: Equatable {
    case notRequested
    case granted
    case denied
}

/// The icon/title/description for one permission state.
struct PermissionPresentation {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

struct PermissionPageScaffold<Features: View>: View {
    let state: PermissionState
    let presentation: PermissionPresentation
    let requestButtonTitle: LocalizedStringKey
    let requestButtonIcon: String
    var requestButtonColor: Color = .mygraBlue
    var isRequestEnabled = true
    let onRequest: () -> Void
    @ViewBuilder let features: () -> Features

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                FeatureCard { features() }

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

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: presentation.icon)
                .font(.system(size: 64))
                .foregroundStyle(presentation.color)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            Text(presentation.title)
                .font(.title.bold())

            Text(presentation.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            statusIndicator
        }
        .padding(.top, 24)
    }

    private var statusText: LocalizedStringKey {
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
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
            .frame(maxWidth: Brand.readableWidth)
            .padding(.horizontal, 20)
            .accessibilityHint(isRequestEnabled ? "Shows the system permission prompt." : "This permission can't be requested right now.")
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
            .frame(maxWidth: Brand.readableWidth)
            .padding(.horizontal, 20)
            .accessibilityHint("Opens the Settings app where you can grant access.")
        case .granted:
            EmptyView()
        }
    }
}

extension PermissionPageScaffold where Features == EmptyView {
    init(
        state: PermissionState,
        presentation: PermissionPresentation,
        requestButtonTitle: LocalizedStringKey,
        requestButtonIcon: String,
        requestButtonColor: Color = .mygraBlue,
        isRequestEnabled: Bool = true,
        onRequest: @escaping () -> Void
    ) {
        self.init(
            state: state,
            presentation: presentation,
            requestButtonTitle: requestButtonTitle,
            requestButtonIcon: requestButtonIcon,
            requestButtonColor: requestButtonColor,
            isRequestEnabled: isRequestEnabled,
            onRequest: onRequest,
            features: { EmptyView() }
        )
    }
}

/// The rounded grouped card that holds feature/privacy rows (hidden when empty).
struct FeatureCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: Brand.readableWidth)
        .padding(.horizontal, 20)
    }
}

/// A single feature/privacy bullet inside a `FeatureCard`.
struct PermissionFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

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
        presentation: PermissionPresentation(icon: "bell.circle.fill", color: .mygraBlue, title: "Enable Notifications", description: "Allow notifications to get weather alerts and migraine reminders."),
        requestButtonTitle: "Allow Notifications",
        requestButtonIcon: "bell.fill",
        onRequest: {}
    ) {
        PermissionFeatureRow(icon: "cloud.sun.fill", iconColor: .orange, title: "Weather Alerts", description: "Get notified about conditions that may trigger migraines.")
    }
}
#endif
