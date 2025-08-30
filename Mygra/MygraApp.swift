//
//  MygraApp.swift
//  Mygra
//
//  Created by Nick Molargik on 7/13/25.
//

import SwiftUI
import SwiftData
import WeatherKit
import BackgroundTasks
import CoreLocation

@main
struct MygraApp: App {
    private let container: ModelContainer
    private let userManager: UserManager
    private let weatherManager: WeatherManager
    private let healthManager: HealthManager
    private let notificationManager: NotificationManager

    // Track last high-risk state to avoid spamming notifications
    @State private var lastWeatherHighRisk: Bool = false

    // Observe the current scene phase for lifecycle changes
    @Environment(\.scenePhase) private var scenePhase

    // Background task identifier (add to Info: BGTaskSchedulerPermittedIdentifiers)
    private let weatherTaskIdentifier = "com.molargiksoftware.Mygra.weatherRefresh"

    init() {
        // MARK: - Diagnostics: identify the intended CloudKit container
        let cloudKitContainerID = "iCloud.com.molargiksoftware.Mygra"
        let cloudDBMode: ModelConfiguration.CloudKitDatabase = .automatic
        print("[Mygra] Creating ModelConfiguration with CloudKit container: \(cloudKitContainerID), database: \(cloudDBMode)")

        do {
            let config = ModelConfiguration(
                cloudKitContainerID,
                cloudKitDatabase: cloudDBMode
            )

            let modelTypeNames = ["User", "Migraine", "WeatherData", "HealthData"]
            print("[Mygra] Registering model types: \(modelTypeNames.joined(separator: ", "))")

            container = try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self,
                configurations: config
            )

            print("[Mygra] ModelContainer created successfully.")
            print("[Mygra] Main context: \(container.mainContext)")
            print("[Mygra] CloudKit-backed configuration in use: YES (if entitlements and container match)")

        } catch {
            fatalError("[Mygra] Failed to initialize ModelContainer: \(error)")
        }

        // Initialize managers with the shared ModelContext
        userManager = UserManager(context: container.mainContext)
        weatherManager = WeatherManager()
        healthManager = HealthManager()
        notificationManager = NotificationManager()

        #if targetEnvironment(simulator)
        print("[Mygra] Running on Simulator. Ensure the Simulator is signed into iCloud in Settings.")
        #else
        print("[Mygra] Running on Device. Ensure the device is signed into iCloud.")
        #endif
        print("[Mygra] If you do not see CloudKit mirroring logs after saves, verify entitlements and container selection in Signing & Capabilities match \(cloudKitContainerID).")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(userManager)
                .environment(weatherManager)
                .environment(healthManager)
                .environment(notificationManager)
                .onAppear {
                    // Safe place to register the background task (escaping closure can capture self)
                    registerBackgroundTaskHandler()
                }
                .task {
                    // Foreground: optionally run periodic checks while app is active
                    await startPeriodicWeatherChecksInForeground()

                    // Ensure a background task is scheduled
                    scheduleWeatherRefreshTask(earliestInMinutes: 90)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background { scheduleWeatherRefreshTask(earliestInMinutes: 90) }
                }
        }
    }

    // MARK: - Background task registration

    private func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: weatherTaskIdentifier, using: nil) { task in
            self.handleWeatherRefreshTask(task: task as! BGAppRefreshTask)
        }
    }

    // MARK: - Background task scheduling/handling

    private func scheduleWeatherRefreshTask(earliestInMinutes minutes: Int) {
        let request = BGAppRefreshTaskRequest(identifier: weatherTaskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[Mygra] Scheduled weather refresh task in ~\(minutes) minutes.")
        } catch {
            print("[Mygra] Failed to schedule weather refresh task: \(error)")
        }
    }

    private func handleWeatherRefreshTask(task: BGAppRefreshTask) {
        // Schedule the next run first to keep the chain alive
        scheduleWeatherRefreshTask(earliestInMinutes: 90)

        // Provide an expiration handler to cancel work if needed
        task.expirationHandler = {
            // Cleanup if you have ongoing work
        }

        Task {
            // Do the work quickly; background time is limited
            await runOneWeatherCheckAndNotifyIfHighRisk()
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - One-shot weather check and notify

    private func isHighRiskWeather() -> Bool {
        // Use WeatherManager’s latest readings
        let humidityHigh: Bool = {
            if let h = weatherManager.humidity { return h >= 0.70 }
            return false
        }()
        let pressureLow: Bool = {
            if let p = weatherManager.pressure {
                let hPa = p.converted(to: .hectopascals).value
                return hPa < 1008.0
            }
            return false
        }()
        let storms: Bool = {
            if let c = weatherManager.condition {
                return c == .strongStorms
            }
            return false
        }()
        return humidityHigh || pressureLow || storms
    }

    private func weatherRiskTitleAndBody() -> (title: String, body: String) {
        var parts: [String] = []
        if let c = weatherManager.condition {
            parts.append(c.description.capitalized)
        }
        if let p = weatherManager.pressure {
            let hPa = p.converted(to: .hectopascals).value
            parts.append(String(format: "%.0f hPa", hPa))
        }
        if let h = weatherManager.humidity {
            parts.append(String(format: "%.0f%% humidity", h * 100.0))
        }
        let summary = parts.isEmpty ? "Current conditions" : parts.joined(separator: " • ")
        return (
            title: "Weather may trigger a migraine",
            body: "\(summary). Consider hydration, rest, and minimizing triggers."
        )
    }

    private func ensureLocationProviderIfMissing() {
        // Background tasks can run when the app hasn’t set a provider yet.
        // Provide a lightweight provider if missing. Here we reuse your LocationManager.
        if weatherManager.locationManager == nil {
            weatherManager.setLocationProvider(LocationManager())
        }
    }

    private func runOneWeatherCheckAndNotifyIfHighRisk() async {
        ensureLocationProviderIfMissing()
        // Do not request notification permission here; it must be granted beforehand.
        await weatherManager.refresh()

        let high = isHighRiskWeather()
        if high && !lastWeatherHighRisk {
            let authorized = await notificationManager.isAuthorized
            if authorized {
                let msg = weatherRiskTitleAndBody()
                await notificationManager.send(
                    title: msg.title,
                    body: msg.body,
                    category: .alert,
                    identifier: "weather-risk-\(Int(Date().timeIntervalSince1970))"
                )
            }
        }
        lastWeatherHighRisk = high
    }

    // MARK: - Foreground periodic checks (optional)

    private func startPeriodicWeatherChecksInForeground() async {
        // Optional: while app is active, keep doing checks
        // Wait until we have a LocationManager (Onboarding/ContentView sets it)
        while weatherManager.locationManager == nil {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }

        // Ask for notification authorization only in foreground UX (e.g., onboarding)
        // await notificationManager.requestAuthorization() // already done in onboarding

        while true {
            await runOneWeatherCheckAndNotifyIfHighRisk()
            try? await Task.sleep(nanoseconds: 90 * 60 * 1_000_000_000)
        }
    }
}
