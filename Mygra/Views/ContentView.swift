//
//  ContentView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

enum AppStage: String, Identifiable {
    case start
    case splash
    case onboarding
    case main
    
    var id: String { self.rawValue }
}

struct ContentView: View {
    @Environment(UserManager.self) private var userManager: UserManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @State private var migraineManager: MigraineManager?

    @State private var appStage: AppStage = .start
    
    var body: some View {
        switch (appStage) {
        case .start:
            ProgressView()
                .task {
                    await prepareApp()
                }
        case .splash:
            SplashView(proceedForward: {
                self.appStage = .onboarding
            })
        case .onboarding:
            OnboardingView(proceedForward: {
                self.appStage = .main
            })
        case .main:
            MainView(
                returnToAppStage: { appStage in
                    self.appStage = appStage
                }
            )
            .environment(migraineManager)
        }
    }
    
    private func prepareApp() async {
        await userManager.refresh()
        
        if let _ = userManager.currentUser {
            Task {
                await healthManager.refreshLatestForToday()
                
                if self.migraineManager == nil {
                    self.migraineManager = MigraineManager(context: userManager.context)
                }
                
                appStage = .main
            }
        } else {
            appStage = .splash
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
    return ContentView()
        .modelContainer(container)
        .environment(previewUserManager)
        .environment(previewHealthManager)
}
