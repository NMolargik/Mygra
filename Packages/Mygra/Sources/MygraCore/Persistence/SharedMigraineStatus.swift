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

    public enum Keys {
        public static let lastMigraineStart = "lastMigraineStart"
        public static let hasOngoingMigraine = "hasOngoingMigraine"
    }

    public static let empty = SharedMigraineStatus(lastMigraineStart: nil, hasOngoingMigraine: false)

    public init(lastMigraineStart: Date?, hasOngoingMigraine: Bool) {
        self.lastMigraineStart = lastMigraineStart
        self.hasOngoingMigraine = hasOngoingMigraine
    }

    // MARK: - Key-value storage

    /// Reads the shared status from a defaults store (normalizing legacy millisecond values).
    public init(defaults: (any KeyValueStoring)?) {
        let raw = defaults?.double(forKey: Keys.lastMigraineStart) ?? 0
        self.lastMigraineStart = Self.date(fromStoredInterval: raw)
        self.hasOngoingMigraine = defaults?.bool(forKey: Keys.hasOngoingMigraine) ?? false
    }

    /// Persists the status to a defaults store.
    public func write(to defaults: (any KeyValueStoring)?) {
        if let start = lastMigraineStart {
            defaults?.set(start.timeIntervalSince1970, forKey: Keys.lastMigraineStart)
        } else {
            defaults?.removeObject(forKey: Keys.lastMigraineStart)
        }
        defaults?.set(hasOngoingMigraine, forKey: Keys.hasOngoingMigraine)
    }

    // MARK: - Wire payload (WatchConnectivity)

    /// The `[String: Any]` form sent over WatchConnectivity (application context,
    /// complication user info, live messages, and status replies).
    public var payload: [String: Any] {
        [
            Keys.lastMigraineStart: lastMigraineStart?.timeIntervalSince1970 ?? 0,
            Keys.hasOngoingMigraine: hasOngoingMigraine,
        ]
    }

    /// Decodes a WatchConnectivity payload. Returns nil when neither key is present.
    public init?(payload: [String: Any]) {
        let rawStart = payload[Keys.lastMigraineStart] as? TimeInterval
        let ongoing = payload[Keys.hasOngoingMigraine] as? Bool
        guard rawStart != nil || ongoing != nil else { return nil }
        self.lastMigraineStart = rawStart.flatMap(Self.date(fromStoredInterval:))
        self.hasOngoingMigraine = ongoing ?? false
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
