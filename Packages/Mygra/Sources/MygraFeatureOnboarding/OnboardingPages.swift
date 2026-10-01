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
            VStack(spacing: 32) {
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

                FeatureCard {
                    PermissionFeatureRow(icon: "iphone", iconColor: .mygraBlue, title: "On-Device Storage", description: "Your migraine data stays on your device and in your personal iCloud.")
                    Divider().padding(.leading, 56)
                    PermissionFeatureRow(icon: "person.fill.checkmark", iconColor: .mygraPurple, title: "Your Data, Your Control", description: "Only you can access your migraine history and health insights.")
                    Divider().padding(.leading, 56)
                    PermissionFeatureRow(icon: "server.rack", iconColor: .mygraBlue, title: "No External Servers", description: "We never send your health data to third-party servers.")
                    Divider().padding(.leading, 56)
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
        )
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
            return PermissionPresentation(icon: "bell.circle.fill", color: .mygraBlue, title: "Enable Notifications", description: "Allow notifications to get weather alerts and migraine reminders.")
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
        }
    }
}

// MARK: - About you

struct OnboardingUserPage: View {
    let user: User

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.mygraBlue)
                        .accessibilityHidden(true)
                    Text("About You")
                        .font(.title.bold())
                    Text("Tell us a bit about yourself so Mygra can personalize insights and track patterns. All data stays on your device or encrypted in iCloud.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                Form {
                    UserEditView(user: user)
                }
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 1600)
                .frame(maxWidth: Brand.readableWidth)

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Complete

struct OnboardingCompletePage: View {
    let onFinish: () -> Void

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

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showContent)
                    .accessibilityHidden(true)
                Text("You're All Set!")
                    .font(.largeTitle.bold())
                Text("Here's what you can do with Mygra")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()

            FeatureCard {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 14) {
                        Image(systemName: feature.icon)
                            .font(.title3)
                            .foregroundStyle(feature.color)
                            .frame(width: 28)
                        Text(feature.title)
                            .font(.body)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : (index.isMultiple(of: 2) ? -30 : 30))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: showContent)

                    if index < features.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }

            Spacer()

            Button {
                Haptics.mediumImpact()
                onFinish()
            } label: {
                HStack(spacing: 8) {
                    Text("Enter Mygra")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.mygraPurple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .frame(maxWidth: Brand.readableWidth)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .background(groupedBackground)
        .task {
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

#Preview("Complete") {
    OnboardingCompletePage(onFinish: {})
}
#endif
