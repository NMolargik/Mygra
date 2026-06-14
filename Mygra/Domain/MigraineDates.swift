//
//  MigraineDates.swift
//  Mygra
//
//  Pure date math shared between the iOS app, widgets, and watch targets.
//

import Foundation

enum MigraineDates {
    /// Whole calendar days between `date` and `now`, never negative.
    /// Both dates are normalized to local midnight so a migraine at 11 PM
    /// counts as "1 day ago" at 1 AM.
    static func daysSince(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let date else { return 0 }
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// The next local midnight (plus a small grace period) after `date`,
    /// used as the widget timeline refresh point.
    static func nextMidnight(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? date.addingTimeInterval(3600)
    }

    /// Elapsed-time string for an ongoing migraine, e.g. "1:02:09" or "4:09".
    static func elapsedString(since start: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
