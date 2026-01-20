//
//  ContentView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(NotificationManager.self) private var notificationManager: NotificationManager
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false

    @Binding var pendingDeepLink: DeepLink?

    @State private var viewModel: ContentView.ViewModel = ViewModel()
    @State private var migraineManager: MigraineManager?
    @State private var insightManager: InsightManager?
    @State private var healthManager: HealthManager = HealthManager()
    @State private var userManager: UserManager?
    @State private var tagManager: TagManager?
    @State private var cloudSyncManager = CloudSyncManager()

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
                        viewModel.appStage = .syncing
                    }
                })
                .id("onboarding")
                .environment(healthManager)
                .environment(weatherManager)
                .environment(userManager)
                .transition(viewModel.leadingTransition)
                .zIndex(1)
                
            case .syncing:
                SyncingView(
                    onSyncComplete: { foundData in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.appStage = .main
                        }
                    }
                )
                .environment(userManager)
                .environment(migraineManager)
                .id("syncing")
                .transition(viewModel.leadingTransition)
                .zIndex(1)
                
            case .main:
                MainView(
                    pendingDeepLink: $pendingDeepLink
                )
                .environment(healthManager)
                .environment(userManager)
                .environment(migraineManager)
                .environment(insightManager)
                .environment(tagManager)
                .environment(cloudSyncManager)
                .id("main")
                .transition(viewModel.leadingTransition)
                .zIndex(0)
            }
        }
        .task {
            // Ensure managers exist in the View
            await MainActor.run {
                // Ensure weatherManager has a location provider
                if weatherManager.locationManager == nil {
                    weatherManager.setLocationProvider(LocationManager())
                }

                if self.migraineManager == nil {
                    self.migraineManager = MigraineManager(context: modelContext)
                }

                if self.userManager == nil {
                    self.userManager = UserManager(context: modelContext)
                }
                
                if self.tagManager == nil {
                    self.tagManager = TagManager(context: modelContext)
                }

                if self.insightManager == nil {
                    guard let userManager, let migraineManager else {
                        // Defer InsightManager initialization until dependencies are ready
                        return
                    }
                    self.insightManager = InsightManager(
                        userManager: userManager,
                        migraineManager: migraineManager,
                        weatherManager: weatherManager,
                        healthManager: healthManager
                    )
                }

                // Configure cloud sync manager with model context
                self.cloudSyncManager.configure(with: modelContext)
            }
            await viewModel.prepareApp(isOnboardingComplete: isOnboardingComplete)
        }
        .onAppear {
            viewModel.configure(cloudSyncManager: cloudSyncManager)
        }
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: User.self, Migraine.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let previewWeatherManager = WeatherManager()
    let previewNotificationManager = NotificationManager()

    return ContentView(pendingDeepLink: .constant(nil))
        .modelContainer(container)
        .environment(previewWeatherManager)
        .environment(previewNotificationManager)
}

