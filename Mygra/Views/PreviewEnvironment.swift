//
//  PreviewEnvironment.swift
//  Mygra
//
//  One-stop dependency graph for SwiftUI previews. Previews are the only
//  place outside the composition root where managers are constructed.
//

import SwiftUI
import SwiftData

@MainActor
struct PreviewEnvironment {
    let container: ModelContainer
    let weatherManager: WeatherManager
    let notificationManager: NotificationManager
    let healthManager: HealthManager
    let migraineManager: MigraineManager
    let userManager: UserManager
    let tagManager: TagManager
    let insightManager: InsightManager
    let cloudSyncManager: CloudSyncManager
    let toastManager: ToastManager

    init(insert: (ModelContext) -> Void = { _ in }) {
        do {
            container = try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self, MigraineTag.self, IntensitySample.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Preview ModelContainer setup failed: \(error)")
        }
        insert(container.mainContext)

        weatherManager = WeatherManager()
        notificationManager = NotificationManager()
        healthManager = HealthManager()
        migraineManager = MigraineManager(container: container, healthManager: healthManager, sharedDefaults: nil)
        userManager = UserManager(container: container)
        tagManager = TagManager(container: container)
        insightManager = InsightManager(
            userManager: userManager,
            migraineManager: migraineManager,
            weatherManager: weatherManager,
            healthManager: healthManager
        )
        cloudSyncManager = CloudSyncManager()
        toastManager = ToastManager()
    }
}

extension View {
    /// Injects a complete preview dependency graph.
    @MainActor
    func previewEnvironment(_ environment: PreviewEnvironment? = nil) -> some View {
        let env = environment ?? PreviewEnvironment()
        return self
            .modelContainer(env.container)
            .environment(env.weatherManager)
            .environment(env.notificationManager)
            .environment(env.healthManager)
            .environment(env.migraineManager)
            .environment(env.userManager)
            .environment(env.tagManager)
            .environment(env.insightManager)
            .environment(env.cloudSyncManager)
            .environment(env.toastManager)
    }
}
