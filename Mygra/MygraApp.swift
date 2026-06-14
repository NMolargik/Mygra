//
//  MygraApp.swift
//  Mygra
//
//  Created by Nick Molargik on 7/13/25.
//
//  Composition root: the model container and every manager are built here,
//  once, and injected into the view tree via .environment().
//

import SwiftUI
import SwiftData
import WeatherKit
import BackgroundTasks
import CoreLocation
import os

@main
struct MygraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.bgWeatherTaskScheduled) private var bgWeatherTaskScheduled: Bool = false

    private let sharedModelContainer: ModelContainer

    // MARK: - Managers (composition root)
    @State private var weatherManager: WeatherManager
    @State private var notificationManager: NotificationManager
    @State private var healthManager: HealthManager
    @State private var migraineManager: MigraineManager
    @State private var userManager: UserManager
    @State private var tagManager: TagManager
    @State private var insightManager: InsightManager
    @State private var cloudSyncManager: CloudSyncManager
    @State private var toastManager: ToastManager
    private let complicationSync: ComplicationSync

    @State private var pendingDeepLink: DeepLink?
    @State private var lastWeatherHighRisk: Bool = false
    private let weatherTaskIdentifier = "com.molargiksoftware.Mygra.weatherRefresh"

    /// True when the process is hosting a unit-test bundle. Under the test
    /// host the app must avoid CloudKit (which traps on a simulator with no
    /// signed-in iCloud account) and background-task scheduling.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    init() {
        // Single shared container, also used by App Intents (see MygraModelContainer).
        sharedModelContainer = MygraModelContainer.shared

        // Build the object graph. The App protocol is @MainActor, so
        // mainContext is reachable here.
        let weather = WeatherManager(locationManager: LocationManager())
        let health = HealthManager()
        let complications = ComplicationSync()
        let migraines = MigraineManager(
            container: sharedModelContainer,
            healthManager: health,
            watchPusher: complications
        )
        complications.commandHandler = migraines
        complications.activate()

        let users = UserManager(container: sharedModelContainer)
        let tags = TagManager(container: sharedModelContainer)
        let insights = InsightManager(
            userManager: users,
            migraineManager: migraines,
            weatherManager: weather,
            healthManager: health
        )

        _weatherManager = State(initialValue: weather)
        _notificationManager = State(initialValue: NotificationManager())
        _healthManager = State(initialValue: health)
        _migraineManager = State(initialValue: migraines)
        _userManager = State(initialValue: users)
        _tagManager = State(initialValue: tags)
        _insightManager = State(initialValue: insights)

        // iCloud sync runs in the background: refresh the in-memory cache
        // whenever CloudKit delivers remote changes (no blocking sync screen).
        let cloudSync = CloudSyncManager()
        cloudSync.onRemoteChange = {
            Task { await migraines.refresh() }
        }
        _cloudSyncManager = State(initialValue: cloudSync)
        _toastManager = State(initialValue: ToastManager())
        complicationSync = complications

        // Skip background-task wiring under the test host: BGTaskScheduler
        // registration/submission is unavailable there and only adds noise.
        if !MygraApp.isRunningTests {
            // Must register handler BEFORE scheduling any tasks
            registerBackgroundTaskHandler()

            if !bgWeatherTaskScheduled {
                scheduleWeatherRefreshTask(earliestInMinutes: 90)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(pendingDeepLink: $pendingDeepLink)
                .toastContainer()
                .modelContainer(sharedModelContainer)
                .onOpenURL { url in
                    if let link = DeepLink(url: url) {
                        pendingDeepLink = link
                    }
                }
                .environment(weatherManager)
                .environment(notificationManager)
                .environment(healthManager)
                .environment(migraineManager)
                .environment(userManager)
                .environment(tagManager)
                .environment(insightManager)
                .environment(cloudSyncManager)
                .environment(toastManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background { scheduleWeatherRefreshTask(earliestInMinutes: 90) }
                    if newPhase == .active { consumePendingDeepLinkFromIntents() }
                }
                .task {
                    consumePendingDeepLinkFromIntents()
                    cloudSyncManager.configure(with: sharedModelContainer.mainContext)
                    await startPeriodicWeatherChecksInForeground()
                }
        }
        .commands {
            MygraCommands(pendingDeepLink: $pendingDeepLink)
        }
    }

    // MARK: - App Intent deep-link hand-off

    /// Picks up a deep link stashed by an `openAppWhenRun` App Intent and
    /// routes it through the normal deep-link path.
    private func consumePendingDeepLinkFromIntents() {
        if let link = DeepLink.takePending(from: UserDefaults(suiteName: AppGroup.id)) {
            pendingDeepLink = link
        }
    }

    // MARK: - Background task registration

    private func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: weatherTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleWeatherRefreshTask(task: refreshTask)
        }
    }

    // MARK: - Background task scheduling/handling

    private func scheduleWeatherRefreshTask(earliestInMinutes minutes: Int) {
        let request = BGAppRefreshTaskRequest(identifier: weatherTaskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try BGTaskScheduler.shared.submit(request)
            bgWeatherTaskScheduled = true
            Log.weather.info("Scheduled weather refresh task in ~\(minutes) minutes.")
        } catch {
            Log.weather.error("Failed to schedule weather refresh task: \(error)")
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

    private var currentRiskInput: WeatherRiskInput {
        WeatherRiskInput(
            humidity: weatherManager.humidity,
            pressureHpa: weatherManager.pressure?.converted(to: .hectopascals).value,
            condition: weatherManager.condition
        )
    }

    private func runOneWeatherCheckAndNotifyIfHighRisk() async {
        // Do not request notification permission here; it must be granted beforehand.
        await weatherManager.refresh()

        let input = currentRiskInput
        let high = WeatherRisk.isHighRisk(input)
        if high && !lastWeatherHighRisk {
            let authorized = await notificationManager.isAuthorized
            if authorized {
                let content = WeatherRisk.notificationContent(input)
                do {
                    try await notificationManager.send(
                        title: content.title,
                        body: content.body,
                        category: .alert,
                        identifier: "weather-risk-\(Int(Date().timeIntervalSince1970))"
                    )
                } catch {
                    Log.weather.error("Failed to send weather-risk notification: \(error)")
                }
            }
        }
        lastWeatherHighRisk = high
    }

    // MARK: - Foreground periodic checks

    private func startPeriodicWeatherChecksInForeground() async {
        while !Task.isCancelled {
            await runOneWeatherCheckAndNotifyIfHighRisk()
            do { try await Task.sleep(for: .seconds(90 * 60)) } catch { return }
        }
    }
}
