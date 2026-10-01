//
//  RootView.swift
//  MygraComposition
//
//  The stage machine (splash → onboarding → main), successor to the old ContentView.
//  Injects every shared @Observable model into the environment so feature views read
//  them without knowing the composition root.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared
import MygraFeatureOnboarding
import MygraServices

public struct RootView: View {
    private let session: SessionController

    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false

    @State private var appStage: AppStage = .splash
    @State private var didShowSyncToast = false
    @State private var wasReturningUser = false

    public init(session: SessionController) {
        self.session = session
    }

    public var body: some View {
        stageView
            .toastContainer()
            .environment(session.migraineData)
            .environment(session.tagData)
            .environment(session.userData)
            .environment(session.insights)
            .environment(session.toastManager)
            .environment(session.cloudSyncManager)
            .environment(session.weatherManager)
            .environment(session.notificationManager)
            .environment(session.healthManager)
    }

    private var stageView: some View {
        ZStack {
            switch appStage {
            case .splash:
                SplashView(onContinue: { advance(to: .onboarding) })
                    .id("splash")
                    .transition(leadingTransition)
                    .zIndex(1)

            case .onboarding:
                OnboardingView(onFinished: {
                    isOnboardingComplete = true
                    advance(to: .main)
                })
                .id("onboarding")
                .transition(leadingTransition)
                .zIndex(1)

            case .main:
                MainView(session: session)
                    .id("main")
                    .transition(leadingTransition)
                    .zIndex(0)
                    .onAppear { handleMainEntry() }
            }
        }
        .task {
            wasReturningUser = isOnboardingComplete
            appStage = isOnboardingComplete ? .main : .splash
        }
    }

    private var leadingTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance(to stage: AppStage) {
        withAnimation(.easeInOut(duration: 0.3)) {
            appStage = stage
        }
    }

    /// iCloud sync runs in the background: returning users with iCloud get a lightweight
    /// toast instead of a blocking screen.
    private func handleMainEntry() {
        guard !didShowSyncToast, wasReturningUser, session.cloudSyncManager.isCloudAvailable else { return }
        didShowSyncToast = true
        session.toastManager.show(message: String(localized: "Syncing with iCloud…"), style: .info, icon: "icloud.fill")
    }
}
#endif
