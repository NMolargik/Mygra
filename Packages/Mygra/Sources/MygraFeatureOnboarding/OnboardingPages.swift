//
//  OnboardingPages.swift
//  MygraFeatureOnboarding
//
//  The six onboarding pages: privacy, location, health, notifications, about you,
//  and complete.
//

#if os(iOS)
import SwiftUI
import CoreLocation
import UserNotifications
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared
import MygraFeatureSettings

// MARK: - Privacy

struct OnboardingPrivacyPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.xxl) {
                OnboardingHeader(
                    systemImage: "lock.shield.fill",
                    tint: .mygraPurple,
                    title: "Your Privacy Matters",
                    description: "Mygra is designed to keep your data private and secure."
                )

                FeatureCard {
                    PermissionFeatureRow(icon: "iphone", iconColor: .mygraBlue, title: "On-Device Storage", description: "Your migraine data stays on your device and in your personal iCloud.")
                    Divider().padding(.leading, 60)
                    PermissionFeatureRow(icon: "person.fill.checkmark", iconColor: .mygraPurple, title: "Your Data, Your Control", description: "Only you can access your migraine history and health insights.")
                    Divider().padding(.leading, 60)
                    PermissionFeatureRow(icon: "server.rack", iconColor: .mygraBlue, title: "No External Servers", description: "We never send your health data to third-party servers.")
                    Divider().padding(.leading, 60)
                    PermissionFeatureRow(icon: "checkmark.shield.fill", iconColor: .green, title: "End-to-End Encrypted", description: "iCloud data is encrypted and only accessible by you.")
                }

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Location

struct OnboardingLocationPage: View {
    @Environment(WeatherManager.self) private var weatherManager

    private var locationManager: LocationManager? { weatherManager.locationManager }

    private var state: PermissionState {
        switch locationManager?.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied, .restricted: return .denied
        default: return .notRequested
        }
    }

    private var presentation: PermissionPresentation {
        guard locationManager != nil else {
            return PermissionPresentation(icon: "location.circle.fill", color: .secondary, title: "Location Unavailable", description: "Location services aren't available right now. You can continue and enable location later in Settings.")
        }
        switch state {
        case .granted:
            return PermissionPresentation(icon: "checkmark.circle.fill", color: .green, title: "Location Enabled", description: "We'll use your location for local weather.")
        case .denied:
            return PermissionPresentation(icon: "location.slash.fill", color: .orange, title: "Location Disabled", description: "Enable location in Settings to get weather data.")
        case .notRequested:
            return PermissionPresentation(icon: "location.circle.fill", color: .mygraBlue, title: "Enable Location", description: "Allow location access to see local weather on your home screen.")
        }
    }

    var body: some View {
        PermissionPageScaffold(
            state: state,
            presentation: presentation,
            requestButtonTitle: "Allow Location Access",
            requestButtonIcon: "location.fill",
            requestButtonColor: .mygraBlue,
            isRequestEnabled: locationManager != nil,
            onRequest: { locationManager?.requestAuthorization() }
        ) {
            PermissionFeatureRow(icon: "sun.max.fill", iconColor: .yellow, title: "Local Weather", description: "See current conditions on your dashboard.")
            Divider().padding(.leading, 60)
            PermissionFeatureRow(icon: "barometer", iconColor: .teal, title: "Pressure Alerts", description: "Get a heads-up when barometric swings make migraines more likely.")
        }
    }
}

// MARK: - Health

struct OnboardingHealthPage: View {
    @Environment(HealthManager.self) private var healthManager

    private var state: PermissionState {
        if healthManager.isAuthorized { return .granted }
        if healthManager.lastError != nil { return .denied }
        return .notRequested
    }

    private var presentation: PermissionPresentation {
        switch state {
        case .granted:
            return PermissionPresentation(icon: "checkmark.circle.fill", color: .green, title: "Health Connected", description: "We'll collect your health information for migraine context.")
        case .denied:
            return PermissionPresentation(icon: "heart.slash.fill", color: .orange, title: "Access Denied", description: "Enable Health access in Settings to collect health information for migraine context.")
        case .notRequested:
            return PermissionPresentation(icon: "heart.fill", color: .pink, title: "Connect Health", description: "Allow access to Health to collect health information for migraine context.")
        }
    }

    var body: some View {
        PermissionPageScaffold(
            state: state,
            presentation: presentation,
            requestButtonTitle: "Connect Apple Health",
            requestButtonIcon: "heart.fill",
            requestButtonColor: .pink,
            onRequest: { Task { await healthManager.requestAuthorization() } }
        ) {
            PermissionFeatureRow(icon: "drop.fill", iconColor: .blue, title: "Hydration & Caffeine", description: "See intake alongside each migraine and log it with Quick Add.")
            Divider().padding(.leading, 60)
            PermissionFeatureRow(icon: "bed.double.fill", iconColor: .indigo, title: "Sleep", description: "Spot short nights that line up with attacks.")
            Divider().padding(.leading, 60)
            PermissionFeatureRow(icon: "brain.head.profile", iconColor: .pink, title: "Headache Records", description: "Completed migraines are written back to Health as headaches.")
        }
    }
}

// MARK: - Notifications

struct OnboardingNotificationPage: View {
    @Environment(NotificationManager.self) private var notificationManager

    private var state: PermissionState {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        default: return .notRequested
        }
    }

    private var presentation: PermissionPresentation {
        switch state {
        case .granted:
            return PermissionPresentation(icon: "checkmark.circle.fill", color: .green, title: "Notifications Enabled", description: "You'll receive alerts about weather and migraine reminders.")
        case .denied:
            return PermissionPresentation(icon: "bell.slash.fill", color: .orange, title: "Notifications Disabled", description: "Enable notifications in Settings to receive alerts.")
        case .notRequested:
            return PermissionPresentation(icon: "bell.badge.fill", color: .mygraBlue, title: "Enable Notifications", description: "Allow notifications to get weather alerts and migraine reminders.")
        }
    }

    var body: some View {
        PermissionPageScaffold(
            state: state,
            presentation: presentation,
            requestButtonTitle: "Allow Notifications",
            requestButtonIcon: "bell.fill",
            onRequest: { Task { try? await notificationManager.requestAuthorization() } }
        ) {
            PermissionFeatureRow(icon: "cloud.sun.fill", iconColor: .orange, title: "Weather Alerts", description: "Get notified about conditions that may trigger migraines.")
            Divider().padding(.leading, 60)
            PermissionFeatureRow(icon: "waveform.path.ecg", iconColor: .mygraPurple, title: "Live Activity", description: "An ongoing migraine shows on your Lock Screen and Dynamic Island.")
        }
    }
}

// MARK: - About you

struct OnboardingUserPage: View {
    let user: User

    var body: some View {
        Form {
            Section {
                OnboardingHeader(
                    systemImage: "person.crop.circle.fill",
                    tint: .mygraBlue,
                    title: "About You",
                    description: "A few details let Mygra personalize insights and spot patterns. Everything stays on your device or encrypted in iCloud, and you can change it anytime."
                )
                .frame(maxWidth: .infinity)
                .padding(.bottom, Brand.Space.sm)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            UserEditView(user: user)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: Brand.readableWidth + 2 * Brand.Space.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Complete

struct OnboardingCompletePage: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false
    @State private var showButton = false

    private let features: [(icon: String, color: Color, title: LocalizedStringKey)] = [
        ("brain.head.profile.fill", .pink, "Track your migraines"),
        ("lightbulb.max.fill", .yellow, "Get intelligent insights"),
        ("chart.line.uptrend.xyaxis", .green, "View trends over time"),
        ("icloud.fill", .mygraBlue, "Sync across devices"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Brand.Space.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 88))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green.gradient)
                    .symbolEffect(.bounce, value: showContent)
                    .accessibilityHidden(true)
                Text("You're All Set!")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Here's what you can do with Mygra")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()

            FeatureCard {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: Brand.Space.md) {
                        Image(systemName: feature.icon)
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(feature.color)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(feature.color.opacity(0.12)))
                            .accessibilityHidden(true)
                        Text(feature.title)
                            .font(.body)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.md)
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent || reduceMotion ? 0 : (index.isMultiple(of: 2) ? -30 : 30))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: showContent)

                    if index < features.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }

            Spacer()

            Button {
                Haptics.mediumImpact()
                onFinish()
            } label: {
                Label("Enter Mygra", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
            .primaryActionButton()
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, Brand.Space.xl)
            .padding(.bottom, Brand.Space.xxl)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .background(groupedBackground)
        .task {
            if reduceMotion {
                showContent = true
                showButton = true
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { showContent = true }
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showButton = true }
        }
    }
}

#Preview("Privacy") {
    OnboardingPrivacyPage()
}

#Preview("About You") {
    OnboardingUserPage(user: User())
}

#Preview("Complete") {
    OnboardingCompletePage(onFinish: {})
}
#endif
