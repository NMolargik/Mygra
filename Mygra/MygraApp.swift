//
//  MygraApp.swift
//  Mygra
//
//  Created by Nick Molargik on 7/13/25.
//

import SwiftUI
import SwiftData

@main
struct MygraApp: App {
    private let container: ModelContainer
    private let userManager: UserManager
    private let weatherManager: WeatherManager
    private let healthManager: HealthManager
    private let notificationManager: NotificationManager

    init() {
        do {
            container = try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self,
                configurations: ModelConfiguration("iCloud.com.molargiksoftware.Mygra")
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        userManager = UserManager(context: container.mainContext)
        weatherManager = WeatherManager()
        healthManager = HealthManager()
        notificationManager = NotificationManager()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(userManager)
                .environment(weatherManager)
                .environment(healthManager)
                .environment(notificationManager)
        }
    }
}
