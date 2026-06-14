//
//  ContentView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(CloudSyncManager.self) private var cloudSyncManager
    @Environment(MigraineManager.self) private var migraineManager
    @Environment(ToastManager.self) private var toastManager
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false

    @Binding var pendingDeepLink: DeepLink?

    @State private var viewModel: ContentView.ViewModel = ViewModel()
    @State private var didShowSyncToast = false
    @State private var wasReturningUser = false

    var body: some View {
        ZStack {
            switch viewModel.appStage {
            case .splash:
                SplashView(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.appStage = .onboarding
                        }
                    }
                )
                .id("splash")
                .transition(viewModel.leadingTransition)
                .zIndex(1)

            case .onboarding:
                OnboardingView(onFinished: {
                    isOnboardingComplete = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.appStage = .main
                    }
                })
                .id("onboarding")
                .transition(viewModel.leadingTransition)
                .zIndex(1)

            case .main:
                MainView(
                    pendingDeepLink: $pendingDeepLink
                )
                .id("main")
                .transition(viewModel.leadingTransition)
                .zIndex(0)
                .onAppear { handleMainEntry() }
            }
        }
        .task {
            wasReturningUser = isOnboardingComplete
            viewModel.prepareApp(isOnboardingComplete: isOnboardingComplete)
        }
    }

    /// On first entry to the main app for a returning user, surface a
    /// lightweight toast so they know iCloud sync is running in the background,
    /// and nudge the local cache in case data arrived before managers were ready.
    private func handleMainEntry() {
        guard !didShowSyncToast, wasReturningUser, cloudSyncManager.isCloudAvailable else { return }
        didShowSyncToast = true

        toastManager.show(message: String(localized: "Syncing with iCloud…"), style: .info, icon: "icloud.fill")

        Task { await migraineManager.refresh() }
    }
}

#Preview {
    let env = PreviewEnvironment()
    ContentView(pendingDeepLink: .constant(nil))
        .previewEnvironment(env)
}
