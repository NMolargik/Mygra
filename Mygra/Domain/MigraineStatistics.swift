//
//  MigraineStatistics.swift
//  Mygra
//
//  Pure statistics over migraine records. No framework dependencies beyond
//  Foundation; everything takes explicit dates/calendars for determinism.
//

import Foundation

enum MigraineStatistics {
    /// Average pain level, or `nil` when the collection is empty.
    static func averageSeverity(_ items: [Migraine]) -> Double? {
        guard !items.isEmpty else { return nil }
        let total = items.reduce(0) { $0 + $1.painLevel }
        return Double(total) / Double(items.count)
    }

    /// Average duration in hours of *completed* migraines, or `nil` when none completed.
    static func averageDurationHours(_ items: [Migraine]) -> Double? {
        let durations = items.compactMap { m -> Double? in
            guard let end = m.endDate else { return nil }
            return max(0, end.timeIntervalSince(m.startDate)) / 3600.0
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    /// The most recent migraine date (end date when completed, start date otherwise).
    static func lastMigraineDate(_ items: [Migraine]) -> Date? {
        items.map { $0.endDate ?? $0.startDate }.max()
    }

    /// Whole days since the most recent migraine ended (or started, if ongoing).
    static func streakDays(_ items: [Migraine], now: Date = Date(), calendar: Calendar = .current) -> Int {
        MigraineDates.daysSince(lastMigraineDate(items), now: now, calendar: calendar)
    }
}
