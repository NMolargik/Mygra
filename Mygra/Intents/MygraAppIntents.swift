//
//  MygraAppIntents.swift
//  Mygra
//
//  Custom App Intents that expose migraine actions to Siri, Shortcuts,
//  Spotlight, and the system. Data-mutating intents run in-process against the
//  shared ModelContainer; navigation intents hand a deep link to the app.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Navigation target (AppEnum)

/// The screens a navigation intent can open. Marked `nonisolated` conformances
/// because `AppEnum` metadata is evaluated off the main actor.
enum MygraScreen: String, AppEnum {
    case dashboard
    case calendar
    case migraines
    case settings
    case assistant

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Mygra Screen"
    }

    nonisolated static var caseDisplayRepresentations: [MygraScreen: DisplayRepresentation] {
        [
            .dashboard: "Dashboard",
            .calendar: "Calendar",
            .migraines: "Migraines",
            .settings: "Settings",
            .assistant: "Migraine Assistant"
        ]
    }

    var deepLink: DeepLink {
        switch self {
        case .dashboard: return .home
        case .calendar: return .calendar
        case .migraines: return .list
        case .settings: return .settings
        case .assistant: return .assistant
        }
    }
}

// MARK: - Shared helpers

private enum IntentSupport {
    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: AppGroup.id) }

    @MainActor static func makeManager() -> MigraineManager {
        MigraineManager(container: MygraModelContainer.shared)
    }
}

// MARK: - Open the app to a screen

struct OpenMygraIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Mygra"
    static let description = IntentDescription("Opens Mygra to a specific screen.")
    static let openAppWhenRun = true

    @Parameter(title: "Screen")
    var screen: MygraScreen

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$screen)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        screen.deepLink.storePending(in: IntentSupport.sharedDefaults)
        return .result()
    }
}

// MARK: - Log a migraine (opens the entry flow)

struct LogMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Migraine"
    static let description = IntentDescription("Opens Mygra to log a new migraine.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.newMigraine.storePending(in: IntentSupport.sharedDefaults)
        return .result()
    }
}

// MARK: - Start tracking an ongoing migraine (background)

struct StartMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Tracking a Migraine"
    static let description = IntentDescription(
        "Immediately starts tracking an ongoing migraine without opening the app."
    )

    @Parameter(title: "Pain Level", default: 5, inclusiveRange: (0, 10))
    var painLevel: Int

    @Parameter(title: "Stress Level", default: 5, inclusiveRange: (0, 10))
    var stressLevel: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Start tracking a migraine with pain \(\.$painLevel)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = IntentSupport.makeManager()
        await manager.refresh()
        guard manager.ongoingMigraine == nil else {
            return .result(dialog: "You already have a migraine in progress.")
        }
        _ = manager.startMigraine(
            painLevel: painLevel,
            stressLevel: stressLevel,
            note: String(localized: "Started with Siri")
        )
        return .result(dialog: "Started tracking your migraine. Feel better soon.")
    }
}

// MARK: - End the ongoing migraine (background)

struct EndMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "End My Migraine"
    static let description = IntentDescription(
        "Marks your ongoing migraine as ended without opening the app."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = IntentSupport.makeManager()
        await manager.refresh()
        let ended = manager.endOngoingMigraine()
        if ended {
            return .result(dialog: "Marked your migraine as ended.")
        } else {
            return .result(dialog: "You don't have a migraine in progress.")
        }
    }
}

// MARK: - Days since last migraine (read-only)

struct DaysSinceLastMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "Days Since Last Migraine"
    static let description = IntentDescription(
        "Tells you how many days it has been since your last migraine."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let manager = IntentSupport.makeManager()
        await manager.refresh()
        let lastDate = MigraineStatistics.lastMigraineDate(manager.migraines)
        guard let lastDate else {
            return .result(value: 0, dialog: "You haven't logged any migraines yet.")
        }
        let days = MigraineDates.daysSince(lastDate)
        let dialog: IntentDialog = days == 0
            ? "Your most recent migraine was today."
            : days == 1
                ? "It's been 1 day since your last migraine."
                : "It's been \(days) days since your last migraine."
        return .result(value: days, dialog: dialog)
    }
}
