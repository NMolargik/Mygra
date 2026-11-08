//
//  SharedMigraineStatus.swift
//  MygraCore
//
//  The migraine status shared through the App Group `UserDefaults` suite and the watch
//  wire protocol. All cross-process reads and writes of widget/watch state go through
//  this type so the key literals exist in exactly one place.
//

import Foundation

nonisolated public struct SharedMigraineStatus: Equatable, Sendable {
    /// Start of the most recent migraine, or `nil` when none have been logged.
    public var lastMigraineStart: Date?
    /// Whether a migraine is currently ongoing.
    public var hasOngoingMigraine: Bool
    /// The ongoing attack's current pain level (0 to 10); nil when none is ongoing.
    public var currentPainLevel: Int?
    /// The user's usual medications for one-tap logging on the watch; empty when no
    /// attack is ongoing.
    public var quickMedications: [QuickMedication]

    public enum Keys {
        public static let lastMigraineStart = "lastMigraineStart"
        public static let hasOngoingMigraine = "hasOngoingMigraine"
        public static let currentPainLevel = "currentPainLevel"
        public static let quickMedications = "quickMedications"
    }

    public static let empty = SharedMigraineStatus(lastMigraineStart: nil, hasOngoingMigraine: false)

    public init(lastMigraineStart: Date?, hasOngoingMigraine: Bool, currentPainLevel: Int? = nil, quickMedications: [QuickMedication] = []) {
        self.lastMigraineStart = lastMigraineStart
        self.hasOngoingMigraine = hasOngoingMigraine
        self.currentPainLevel = currentPainLevel
        self.quickMedications = quickMedications
    }

    // MARK: - Key-value storage

    /// Reads the shared status from a defaults store (normalizing legacy millisecond values).
    public init(defaults: (any KeyValueStoring)?) {
        let raw = defaults?.double(forKey: Keys.lastMigraineStart) ?? 0
        self.lastMigraineStart = Self.date(fromStoredInterval: raw)
        self.hasOngoingMigraine = defaults?.bool(forKey: Keys.hasOngoingMigraine) ?? false
        self.currentPainLevel = defaults?.object(forKey: Keys.currentPainLevel) as? Int
        self.quickMedications = defaults?.data(forKey: Keys.quickMedications)
            .flatMap { try? JSONDecoder().decode([QuickMedication].self, from: $0) } ?? []
    }

    /// Persists the status to a defaults store.
    public func write(to defaults: (any KeyValueStoring)?) {
        if let start = lastMigraineStart {
            defaults?.set(start.timeIntervalSince1970, forKey: Keys.lastMigraineStart)
        } else {
            defaults?.removeObject(forKey: Keys.lastMigraineStart)
        }
        defaults?.set(hasOngoingMigraine, forKey: Keys.hasOngoingMigraine)
        if let currentPainLevel {
            defaults?.set(currentPainLevel, forKey: Keys.currentPainLevel)
        } else {
            defaults?.removeObject(forKey: Keys.currentPainLevel)
        }
        if quickMedications.isEmpty {
            defaults?.removeObject(forKey: Keys.quickMedications)
        } else {
            defaults?.set(try? JSONEncoder().encode(quickMedications), forKey: Keys.quickMedications)
        }
    }

    // MARK: - Wire payload (WatchConnectivity)

    /// The `[String: Any]` form sent over WatchConnectivity (application context,
    /// complication user info, live messages, and status replies).
    public var payload: [String: Any] {
        var dictionary: [String: Any] = [
            Keys.lastMigraineStart: lastMigraineStart?.timeIntervalSince1970 ?? 0,
            Keys.hasOngoingMigraine: hasOngoingMigraine,
        ]
        if let currentPainLevel { dictionary[Keys.currentPainLevel] = currentPainLevel }
        dictionary[Keys.quickMedications] = quickMedications.map(\.payload)
        return dictionary
    }

    /// Decodes a WatchConnectivity payload. Returns nil when neither key is present.
    public init?(payload: [String: Any]) {
        let rawStart = payload[Keys.lastMigraineStart] as? TimeInterval
        let ongoing = payload[Keys.hasOngoingMigraine] as? Bool
        guard rawStart != nil || ongoing != nil else { return nil }
        self.lastMigraineStart = rawStart.flatMap(Self.date(fromStoredInterval:))
        self.hasOngoingMigraine = ongoing ?? false
        self.currentPainLevel = payload[Keys.currentPainLevel] as? Int
        self.quickMedications = (payload[Keys.quickMedications] as? [[String: Any]])?.compactMap(QuickMedication.init(payload:)) ?? []
    }

    /// Normalizes any legacy values stored in milliseconds; zero means "none".
    public static func date(fromStoredInterval raw: TimeInterval) -> Date? {
        let seconds = raw > 10_000_000_000 ? raw / 1000.0 : raw
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }
}

extension KeyValueStoring {
    /// Reads the shared migraine status.
    public func readSharedStatus() -> SharedMigraineStatus {
        SharedMigraineStatus(defaults: self)
    }

    /// Writes the shared migraine status.
    public func writeSharedStatus(_ status: SharedMigraineStatus) {
        status.write(to: self)
    }
}
