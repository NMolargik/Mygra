//
//  SharedStatus.swift
//  Mygra
//
//  Shared between the iOS app, iOS widgets, watch app, and watch widgets.
//

import Foundation

/// App Group constants shared across every target.
enum AppGroup {
    static let id = "group.com.molargiksoftware.Mygra"
}

/// The migraine status shared through the App Group `UserDefaults` suite.
/// All cross-process reads and writes of widget/watch state go through this
/// type so the key literals exist in exactly one place.
struct SharedMigraineStatus: Equatable, Sendable {
    /// Start of the most recent migraine, or `nil` when none have been logged.
    var lastMigraineStart: Date?
    /// Whether a migraine is currently ongoing.
    var hasOngoingMigraine: Bool

    enum Keys {
        static let lastMigraineStart = "lastMigraineStart"
        static let hasOngoingMigraine = "hasOngoingMigraine"
    }

    init(lastMigraineStart: Date?, hasOngoingMigraine: Bool) {
        self.lastMigraineStart = lastMigraineStart
        self.hasOngoingMigraine = hasOngoingMigraine
    }

    /// Reads the shared status from a defaults store (typically the App Group suite).
    init(defaults: UserDefaults?) {
        let raw = defaults?.double(forKey: Keys.lastMigraineStart) ?? 0
        // Normalize any legacy values stored in milliseconds.
        let seconds = raw > 10_000_000_000 ? raw / 1000.0 : raw
        self.lastMigraineStart = seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        self.hasOngoingMigraine = defaults?.bool(forKey: Keys.hasOngoingMigraine) ?? false
    }

    /// Persists the status to a defaults store.
    func write(to defaults: UserDefaults?) {
        if let start = lastMigraineStart {
            defaults?.set(start.timeIntervalSince1970, forKey: Keys.lastMigraineStart)
        } else {
            defaults?.removeObject(forKey: Keys.lastMigraineStart)
        }
        defaults?.set(hasOngoingMigraine, forKey: Keys.hasOngoingMigraine)
    }
}
