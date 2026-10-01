//
//  Seams.swift
//  MygraCore
//
//  Protocol seams over system frameworks so everything above them is testable with
//  in-memory fakes. Production conformances live in MygraServices (or the app target
//  when the framework type can't live in a package).
//

import Foundation

// MARK: - Key-value storage

/// The slice of `UserDefaults` the app uses (standard defaults and the App Group suite).
nonisolated public protocol KeyValueStoring: AnyObject {
    func bool(forKey defaultName: String) -> Bool
    func double(forKey defaultName: String) -> Double
    func integer(forKey defaultName: String) -> Int
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    /// The raw stored value, used to tell "never set" apart from `false`/`0`.
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}

// MARK: - Widgets

/// WidgetCenter timeline reloads.
@MainActor
public protocol WidgetTimelineReloading {
    func reloadTimelines(ofKind kind: String)
}

/// Widget kinds shared between the app (which reloads them) and the extensions.
nonisolated public enum WidgetKind {
    public static let daysSinceLastMigraine = "DaysSinceLastMigraine"
    public static let daysSinceLastMigraineWatch = "DaysSinceLastMigraineWatch"
}

// MARK: - Watch

/// Pushes the shared migraine status to the paired watch.
@MainActor
public protocol WatchStatusPushing: AnyObject {
    func pushStatus(_ status: SharedMigraineStatus)
}

// MARK: - Live Activity

/// The ongoing-migraine Live Activity lifecycle (ActivityKit impl in MygraServices).
@MainActor
public protocol MigraineActivityControlling {
    /// Starts an activity for the migraine unless one already exists (folding duplicates).
    func ensureStarted(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String)
    /// Updates the levels/note shown on the activity.
    func update(for migraineID: UUID, painLevel: Int, stressLevel: Int, note: String)
    /// Ends the activity for the migraine, if any.
    func end(for migraineID: UUID)
}

// MARK: - Health

/// Writes completed headaches to Health (HealthKit impl in MygraServices).
@MainActor
public protocol HeadacheRecording: AnyObject {
    func recordHeadache(start: Date, end: Date, severity: Severity) async throws
}

// MARK: - Spotlight

/// Abstraction over Spotlight's semantic index. The concrete indexer lives in the app
/// target (it maps models to `AppEntity` types, which can't live in the package).
@MainActor
public protocol MigraineIndexing {
    /// Replaces the index contents with entries for the given migraines.
    func reindex(migraines: [Migraine])
}

// MARK: - Siri on-screen awareness

/// Tags the detail screen's `NSUserActivity` with the migraine's App Intents entity
/// identifier so Siri can resolve "this migraine" from what's on screen (AppIntents
/// impl in the app target, where the entity type lives).
@MainActor
public protocol MigraineActivityAnnotating {
    func annotate(_ activity: NSUserActivity, migraineID: UUID)
}

// MARK: - App Intents donation

/// The user actions Siri can learn to predict.
nonisolated public enum DonatableAction: Sendable, Equatable {
    case startMigraine
    case endMigraine
}

/// Donates an intent so Siri can suggest it (AppIntents impl in the app target).
@MainActor
public protocol IntentDonating {
    func donate(_ action: DonatableAction)
}

// MARK: - App Store review

/// Requests a review prompt (StoreKit impl in the app target, which owns the scene).
@MainActor
public protocol ReviewRequesting {
    func requestReview()
}

// MARK: - Notifications

/// Local notification delivery (UserNotifications impl in MygraServices).
@MainActor
public protocol LocalNotifying: AnyObject {
    var isAuthorized: Bool { get async }
    func send(title: String, body: String, identifier: String) async throws
}

// MARK: - Weather

/// The current-conditions surface the risk notifier needs (WeatherKit impl in MygraServices).
@MainActor
public protocol CurrentWeatherProviding: AnyObject {
    /// Refreshes current conditions (throttled by the implementation).
    func refresh() async
    /// The readings that feed `WeatherRisk`.
    var riskInput: WeatherRiskInput { get }
}

// MARK: - Apple Intelligence

/// The on-device intelligence surface (Foundation Models impl in MygraServices).
@MainActor
public protocol MigraineIntelligence: AnyObject {
    /// Whether the system language model is available and ready.
    var isAvailable: Bool { get }
    /// The chat transcript (system turns included).
    var conversation: [ChatMessage] { get }
    var isChatActive: Bool { get }

    /// A concise explanation of likely contributing factors for one migraine.
    func analyze(migraine: Migraine, user: User?) async throws -> String?
    /// A short description + one recommendation for an insight.
    func explain(insight: Insight, user: User?) async throws -> QuickBitExplanation?
    /// Seeds a chat session with the user profile and migraine history.
    func startChat(migraines: [Migraine], user: User?) async
    /// Sends a user message and returns the assistant reply.
    func send(message: String) async throws -> String
    /// Clears the chat state.
    func resetChat()
}
