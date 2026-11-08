//
//  MigraineRecency.swift
//  MygraCore
//
//  How long ago the last migraine was, in the units a person would say out loud, so the
//  dashboard header can say it once and accurately ("20 hours ago", not "today").
//

import Foundation

public enum MigraineRecency: Equatable, Sendable {
    /// Nothing logged yet.
    case none
    /// An attack is in progress.
    case ongoing
    /// Ended less than an hour ago.
    case withinHour
    /// Ended 1 to 23 hours ago.
    case hoursAgo(Int)
    /// Ended 1 to 6 calendar days ago: "Last migraine 3 days ago".
    case daysAgo(Int)
    /// Seven or more calendar days: celebrated as a streak, "No migraines in 12 days".
    case migraineFree(days: Int)

    /// Days from which the header switches from "last migraine" to a migraine-free streak.
    public static let streakThresholdDays = 7

    public static func of(_ items: [Migraine], hasOngoing: Bool, now: Date = Date(), calendar: Calendar = .current) -> MigraineRecency {
        if hasOngoing { return .ongoing }
        guard let last = MigraineStatistics.lastMigraineDate(items) else { return .none }
        let elapsed = max(0, now.timeIntervalSince(last))
        if elapsed < 3600 { return .withinHour }
        if elapsed < 24 * 3600 { return .hoursAgo(Int(elapsed / 3600)) }
        let days = max(1, MigraineDates.daysSince(last, now: now, calendar: calendar))
        return days >= streakThresholdDays ? .migraineFree(days: days) : .daysAgo(days)
    }
}
