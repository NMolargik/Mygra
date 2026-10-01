//
//  MigraineStatistics.swift
//  MygraCore
//
//  Pure statistics over migraine records. Everything takes explicit dates/calendars
//  for determinism.
//

import Foundation

public enum MigraineStatistics {
    /// Average pain level, or `nil` when the collection is empty.
    public static func averageSeverity(_ items: [Migraine]) -> Double? {
        guard !items.isEmpty else { return nil }
        let total = items.reduce(0) { $0 + $1.painLevel }
        return Double(total) / Double(items.count)
    }

    /// Average duration in hours of *completed* migraines, or `nil` when none completed.
    public static func averageDurationHours(_ items: [Migraine]) -> Double? {
        let durations = items.compactMap { migraine -> Double? in
            guard let end = migraine.endDate else { return nil }
            return max(0, end.timeIntervalSince(migraine.startDate)) / 3600.0
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    /// The most recent migraine date (end date when completed, start date otherwise).
    public static func lastMigraineDate(_ items: [Migraine]) -> Date? {
        items.map { $0.endDate ?? $0.startDate }.max()
    }

    /// Whole days since the most recent migraine ended (or started, if ongoing).
    public static func streakDays(_ items: [Migraine], now: Date = Date(), calendar: Calendar = .current) -> Int {
        MigraineDates.daysSince(lastMigraineDate(items), now: now, calendar: calendar)
    }

    /// Migraines whose start falls on the same calendar day as `date`.
    public static func migraines(_ items: [Migraine], on date: Date, calendar: Calendar = .current) -> [Migraine] {
        items.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }
}

// MARK: - List grouping

/// One month's worth of migraines, newest first — a section in the Migraines list.
nonisolated public struct MigraineMonthGroup: Identifiable, Equatable, Sendable {
    /// The first instant of the month (the section identity).
    public let monthStart: Date
    public let migraineIDs: [UUID]

    public var id: Date { monthStart }

    public init(monthStart: Date, migraineIDs: [UUID]) {
        self.monthStart = monthStart
        self.migraineIDs = migraineIDs
    }
}

extension MigraineStatistics {
    /// Groups migraines by the calendar month they started in, newest month first and
    /// newest migraine first within each month. Order of `items` does not matter.
    public static func monthGroups(_ items: [Migraine], calendar: Calendar = .current) -> [MigraineMonthGroup] {
        let sorted = items.sorted { $0.startDate > $1.startDate }
        var groups: [MigraineMonthGroup] = []
        var buckets: [Date: [UUID]] = [:]
        var order: [Date] = []
        for migraine in sorted {
            let start = calendar.dateInterval(of: .month, for: migraine.startDate)?.start ?? migraine.startDate
            if buckets[start] == nil { order.append(start) }
            buckets[start, default: []].append(migraine.id)
        }
        for start in order {
            groups.append(MigraineMonthGroup(monthStart: start, migraineIDs: buckets[start] ?? []))
        }
        return groups
    }
}
