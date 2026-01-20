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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.bgWeatherTaskScheduled) private var bgWeatherTaskScheduled: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.isOnboardingComplete) private var isOnboardingComplete: Bool = false
    
    private let sharedModelContainer: ModelContainer

    init() {
        let cloudKitContainerID = "iCloud.com.molargiksoftware.Mygra"

        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .private(cloudKitContainerID)
            )

            sharedModelContainer = try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self, MigraineTag.self, IntensitySample.self,
                configurations: config
            )
        } catch {
            fatalError("[Mygra] Failed to initialize ModelContainer: \(error)")
        }
        
        // Configure TipKit
        // try? Tips.configure([
        //      .displayFrequency(.immediate)
        // ])
        
        weatherManager = WeatherManager()
        notificationManager = NotificationManager()

        // Must register handler BEFORE scheduling any tasks
        registerBackgroundTaskHandler()

        if !bgWeatherTaskScheduled {
            scheduleWeatherRefreshTask(earliestInMinutes: 90)
        }
        ensureLocationProviderIfMissing()
        print(weatherManager.locationManager == nil ? "No location manager" : "Has location manager")
        
        // watchOS
        ComplicationSync.shared.activate()
    }
    
    @State private var pendingDeepLink: DeepLink?
    @State private var lastWeatherHighRisk: Bool = false
    @State private var notificationManager: NotificationManager
    @State private var weatherManager: WeatherManager
    private let weatherTaskIdentifier = "com.molargiksoftware.Mygra.weatherRefresh"

    var body: some Scene {
        WindowGroup {
            ContentView(pendingDeepLink: $pendingDeepLink)
                .modelContainer(sharedModelContainer)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .environment(weatherManager)
                .environment(notificationManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background { scheduleWeatherRefreshTask(earliestInMinutes: 90) }
                }
                .task {
                    await startPeriodicWeatherChecksInForeground()
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mygra" else { return }

        switch url.host {
        case "new-migraine":
            pendingDeepLink = .newMigraine
        case "home":
            pendingDeepLink = .home
        default:
            break
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
            bgWeatherTaskScheduled = true
            print("[Mygra] Scheduled weather refresh task in ~\(minutes) minutes.")
        } catch {
            print("[Mygra] Failed to schedule weather refresh task: \(error)")
        }
    }

    private func handleWeatherRefreshTask(task: BGAppRefreshTask) {
        bgWeatherTaskScheduled = false
        scheduleWeatherRefreshTask(earliestInMinutes: 90)

        Task {
            await runOneWeatherCheckAndNotifyIfHighRisk()
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - One-shot weather check and notify

    private func isHighRiskWeather() -> Bool {
        // Use WeatherManager's latest readings
        let humidityHigh: Bool = {
            if let humidity = weatherManager.humidity { return humidity >= 0.70 }
            return false
        }()
        let pressureLow: Bool = {
            if let pressure = weatherManager.pressure {
                let hPa = pressure.converted(to: .hectopascals).value
                return hPa < 1008.0
            }
            return false
        }()
        let storms: Bool = {
            if let condition = weatherManager.condition {
                return condition == .strongStorms
            }
            return false
        }()
        return humidityHigh || pressureLow || storms
    }

    private func weatherRiskTitleAndBody() -> (title: String, body: String) {
        var parts: [String] = []
        if let condition = weatherManager.condition {
            parts.append(condition.description.capitalized)
        }
        if let pressure = weatherManager.pressure {
            let hPa = pressure.converted(to: .hectopascals).value
            parts.append(String(format: "%.0f hPa", hPa))
        }
        if let humidity = weatherManager.humidity {
            parts.append(String(format: "%.0f%% humidity", humidity * 100.0))
        }
        let summary = parts.isEmpty ? "Current conditions" : parts.joined(separator: " • ")
        return (
            title: "Weather may trigger a migraine",
            body: "\(summary). Consider hydration, rest, and minimizing triggers."
        )
    }

    private func ensureLocationProviderIfMissing() {
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
                do {
                    try await notificationManager.send(
                        title: weatherRiskTitleAndBody().title,
                        body: weatherRiskTitleAndBody().body,
                        category: .alert,
                        identifier: "weather-risk-\(Int(Date().timeIntervalSince1970))"
                    )
                } catch let error as NotificationError {
                    print("[Mygra] Notification error: \(error.localizedDescription)")
                } catch {
                    print("[Mygra] Unexpected error sending notification: \(error)")
                }
            }
        }
        lastWeatherHighRisk = high
    }

    // MARK: - Foreground periodic checks (optional)

    private func startPeriodicWeatherChecksInForeground() async {
        while weatherManager.locationManager == nil {
            if Task.isCancelled { return }
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
        }

        while true {
            if Task.isCancelled { return }
            await runOneWeatherCheckAndNotifyIfHighRisk()
            if Task.isCancelled { return }
            do { try await Task.sleep(nanoseconds: 90 * 60 * 1_000_000_000) } catch { return }
        }
    }
}
