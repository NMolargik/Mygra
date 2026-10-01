//
//  PermissionPageScaffold.swift
//  MygraFeatureOnboarding
//
//  Shared layout for the permission pages (Health, Location, Notifications): a large
//  animated status symbol, title, description, status pill, optional feature list, and
//  an action button whose behavior follows `state`. The HIG asks for the "why" before
//  the system prompt, so the request button is the explicit opt-in.
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
    @ContentBuilder let features: () -> Features

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.xxl) {
                OnboardingHeader(
                    systemImage: presentation.icon,
                    tint: presentation.color,
                    title: presentation.title,
                    description: presentation.description
                ) {
                    statusIndicator
                }

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

    private var statusText: LocalizedStringKey {
        switch state {
        case .notRequested: return "Optional — you can enable this later"
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
            Image(systemName: state == .granted ? "checkmark.circle.fill" : (state == .denied ? "exclamationmark.circle.fill" : "circle.dashed"))
                .foregroundStyle(statusColor)
                .contentTransition(.symbolEffect(.replace))
            Text(statusText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Brand.Space.md)
        .padding(.vertical, 6)
        .statPillBackground()
        .accessibilityElement(children: .combine)
    }

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
                    .frame(height: 24)
            }
            .primaryActionButton(tint: requestButtonColor)
            .disabled(!isRequestEnabled)
            .padding(.horizontal, Brand.Space.xl)
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
                    .frame(height: 24)
            }
            .secondaryActionButton(tint: .orange)
            .padding(.horizontal, Brand.Space.xl)
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

/// The large tinted symbol + title + description every onboarding page opens with.
/// The symbol bounces in on appear and swaps with a replace effect when it changes.
struct OnboardingHeader<Accessory: View>: View {
    let systemImage: String
    let tint: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    @ContentBuilder let accessory: () -> Accessory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    init(
        systemImage: String,
        tint: Color,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        @ContentBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.description = description
        self.accessory = accessory
    }

    var body: some View {
        VStack(spacing: Brand.Space.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint.gradient)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating.speed(100) : .nonRepeating, value: bounce)
                .frame(height: 80)
                .accessibilityHidden(true)

            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Brand.readableWidth)
                .padding(.horizontal, Brand.Space.xl)

            accessory()
        }
        .padding(.top, Brand.Space.xl)
        .onAppear { bounce.toggle() }
    }
}

/// The rounded grouped card that holds feature/privacy rows (hidden when empty).
struct FeatureCard<Content: View>: View {
    @ContentBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
        .frame(maxWidth: Brand.readableWidth)
        .padding(.horizontal, Brand.Space.xl)
    }
}

/// A single feature/privacy bullet inside a `FeatureCard`.
struct PermissionFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(iconColor.opacity(0.12)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Brand.Space.lg)
        .padding(.vertical, Brand.Space.md)
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
