//
//  MygraApp.swift
//  Mygra
//
//  Thin shell: builds the SessionController (composition root in MygraComposition),
//  registers it for App Intents, hosts the window, and owns the things only an app
//  process can: BGTaskScheduler registration, the foreground weather-risk timer, and
//  Home Screen quick actions. All feature code lives in Packages/Mygra.
//

import AppIntents
import BackgroundTasks
import SwiftData
import SwiftUI
import MygraComposition
import MygraCore
import MygraData
import MygraServices
import os

@main
struct MygraApp: App {
    @UIApplicationDelegateAdaptor(QuickActionAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.bgWeatherTaskScheduled) private var bgWeatherTaskScheduled: Bool = false

    @State private var quickActions = QuickActionRelay.shared
    private let session: SessionController

    /// True when the process is hosting a unit-test bundle. Under the test host the app
    /// must avoid CloudKit (which traps on a simulator with no signed-in iCloud account)
    /// and background-task scheduling.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// One CloudKit-free container for the whole test-host process, backed by a unique
    /// on-disk temp store: in-memory stores share a /dev/null SQLite identity and crash
    /// SwiftData on the first fetch in the simulator, and SwiftUI may construct the
    /// `App` value more than once at launch.
    private static let testContainer: ModelContainer = (try? MygraStore.makeTemporaryContainer()) ?? MygraStore.makeContainer(inMemory: true)

    init() {
        let session = SessionController(
            container: Self.isRunningTests ? Self.testContainer : nil,
            indexer: Self.isRunningTests ? nil : SpotlightIndexer(),
            reviewRequester: AppStoreReviewRequester(),
            intentDonor: Self.isRunningTests ? nil : IntentDonor(),
            activityAnnotator: MigraineActivityAnnotator()
        )
        self.session = session

        // Expose the session to App Intents (Siri, Shortcuts, Spotlight).
        AppDependencyManager.shared.add(dependency: session)

        if !Self.isRunningTests {
            BackgroundWeatherRefresh.register(session: session)
            if !bgWeatherTaskScheduled {
                bgWeatherTaskScheduled = BackgroundWeatherRefresh.schedule()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .modelContainer(session.container)
                .onOpenURL { url in
                    session.handle(url: url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background where !Self.isRunningTests:
                        bgWeatherTaskScheduled = BackgroundWeatherRefresh.schedule()
                    case .active:
                        session.consumePendingDeepLinkFromIntents()
                        consumeQuickAction()
                    default:
                        break
                    }
                }
                .onChange(of: quickActions.url) { _, _ in consumeQuickAction() }
                .task {
                    session.start()
                    consumeQuickAction()
                    await session.notificationManager.refreshAuthorizationStatus()
                    guard !Self.isRunningTests else { return }
                    await runForegroundWeatherChecks()
                }
        }
        .commands {
            MygraCommands(session: session)
        }
    }

    /// Routes a Home Screen quick action through the same deep-link path as URLs.
    private func consumeQuickAction() {
        guard let url = quickActions.url else { return }
        quickActions.url = nil
        session.handle(url: url)
    }

    /// Checks the weather every 90 minutes while the app is in the foreground.
    private func runForegroundWeatherChecks() async {
        while !Task.isCancelled {
            await session.checkWeatherRisk()
            do { try await Task.sleep(for: .seconds(BackgroundWeatherRefresh.interval)) } catch { return }
        }
    }
}

// MARK: - Background weather refresh

/// The BGAppRefresh task that re-checks weather risk roughly every 90 minutes.
enum BackgroundWeatherRefresh {
    static let identifier = "com.molargiksoftware.Mygra.weatherRefresh"
    /// Seconds between checks.
    static let interval: TimeInterval = 90 * 60

    /// Registers the handler. Must run before any task is scheduled.
    static func register(session: SessionController) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let box = UncheckedSendableBox(value: refreshTask)
            Task { @MainActor in
                _ = schedule()
                await session.checkWeatherRisk()
                box.value.setTaskCompleted(success: true)
            }
        }
    }

    /// Schedules the next refresh. Returns whether submission succeeded.
    @discardableResult
    static func schedule() -> Bool {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(interval)
        do {
            try BGTaskScheduler.shared.submit(request)
            Log.weather.info("Scheduled weather refresh task")
            return true
        } catch {
            Log.weather.error("Failed to schedule weather refresh task: \(error.localizedDescription)")
            return false
        }
    }
}
