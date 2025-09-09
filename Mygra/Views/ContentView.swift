//
//  ContentView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(UserManager.self) private var userManager: UserManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    
    @State private var viewModel: ContentView.ViewModel = ViewModel()
    @State private var migraineManager: MigraineManager?
    @State private var insightManager: InsightManager?

    var body: some View {
        ZStack {
            switch (viewModel.appStage) {
            case .start:
                ProgressView()
                    .id("start")
                    .zIndex(0)
                    .task {
                        await prepareApp()
                    }
            case .splash:
                SplashView(proceedForward: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.appStage = .onboarding
                    }
                }, refreshUser: {
                    Task { await refreshUser() }
                })
                .id("splash")
                .transition(viewModel.leadingTransition)
                .zIndex(1)
            case .onboarding:
                OnboardingView(proceedForward: {
                    if self.migraineManager == nil {
                        self.migraineManager = MigraineManager(context: userManager.context, healthManager: healthManager)
                    }
                    
                    if self.insightManager == nil {
                        self.insightManager = InsightManager(
                            userManager: userManager,
                            migraineManager: migraineManager!,
                            weatherManager: weatherManager,
                            healthManager: healthManager
                        )
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.appStage = .main
                    }
                })
                .id("onboarding")
                .transition(viewModel.leadingTransition)
                .zIndex(1)
            case .main:
                MainView(
                    returnToAppStage: { stage in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.appStage = stage
                        }
                    },
                    pendingDeepLinkID: $viewModel.pendingDeepLinkID,
                    pendingDeepLinkAction: $viewModel.pendingDeepLinkAction
                )
                .environment(migraineManager)
                .environment(insightManager)
                .id("main")
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.appStage)
        // Handle incoming deep links like mygra://migraine/<uuid>?action=end
        .onOpenURL { url in
            let shouldGoToMain = viewModel.handleOpenURL(url)
            if shouldGoToMain {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.appStage = .main
                }
            }
        }
    }
    
    private func prepareApp() async {
        // Initial local fetch
        await userManager.refresh()

        // If no user yet, attempt a restore window from iCloud before deciding onboarding
        if userManager.currentUser == nil {
            await userManager.restoreFromCloud(timeout: 1, pollInterval: 1.0)
        }
        
        if let _ = userManager.currentUser {
            Task {
                await healthManager.refreshLatestForToday()
                
                if self.migraineManager == nil {
                    self.migraineManager = MigraineManager(context: userManager.context, healthManager: healthManager)
                }
                
                if self.weatherManager.locationManager == nil {
                    self.weatherManager.setLocationProvider(LocationManager())
                }
                
                if self.insightManager == nil {
                    self.insightManager = InsightManager(
                        userManager: userManager,
                        migraineManager: migraineManager!,
                        weatherManager: weatherManager,
                        healthManager: healthManager
                    )
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.appStage = .main
                }
            }
        } else {
            // Still no user after the restore window → onboarding
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.appStage = .splash
            }
        }
    }
    
    // Attempt another iCloud restore when the user requests a refresh on the splash screen.
    private func refreshUser() async {
        // Re-fetch local state first
        await userManager.refresh()
        // Try another iCloud restore attempt (slightly longer timeout to improve chances)
        await userManager.restoreFromCloud(timeout: 2, pollInterval: 1.0)
        
        guard userManager.currentUser != nil else {
            // Stay on splash if we still don't have a user
            return
        }
        
        // Initialize managers and move to main, mirroring prepareApp happy path
        await healthManager.refreshLatestForToday()
        
        if self.migraineManager == nil {
            self.migraineManager = MigraineManager(context: userManager.context, healthManager: healthManager)
        }
        
        if self.weatherManager.locationManager == nil {
            self.weatherManager.setLocationProvider(LocationManager())
        }
        
        if self.insightManager == nil {
            self.insightManager = InsightManager(
                userManager: userManager,
                migraineManager: migraineManager!,
                weatherManager: weatherManager,
                healthManager: healthManager
            )
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.appStage = .main
        }
    }
}

#Preview {
    // Set up a preview SwiftData in-memory container
    let container: ModelContainer
    do {
        container = try ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let previewUserManager = UserManager(context: container.mainContext)
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()
    let previewNotificationManager = NotificationManager()
    return ContentView()
        .modelContainer(container)
        .environment(previewUserManager)
        .environment(previewHealthManager)
        .environment(previewWeatherManager)
        .environment(previewNotificationManager)
}
