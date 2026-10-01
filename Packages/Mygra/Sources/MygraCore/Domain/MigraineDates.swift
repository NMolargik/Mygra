//
//  MigraineDates.swift
//  MygraCore
//
//  Pure date math shared between the iOS app, widgets, and watch targets.
//

import Foundation

nonisolated public enum MigraineDates {
    /// Whole calendar days between `date` and `now`, never negative. Both dates are
    /// normalized to local midnight so a migraine at 11 PM counts as "1 day ago" at 1 AM.
    public static func daysSince(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let date else { return 0 }
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// The next local midnight (plus a small grace period) after `date`, used as the
    /// widget timeline refresh point.
    public static func nextMidnight(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? date.addingTimeInterval(3600)
    }

    /// Elapsed-time string for an ongoing migraine, e.g. "1:02:09" or "4:09".
    public static func elapsedString(since start: Date, now: Date = Date()) -> String {
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

    /// Duration string with unit suffixes, e.g. "2h 05m 09s" or "4m 09s".
    public static func durationString(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, secs)
        } else {
            return String(format: "%dm %02ds", minutes, secs)
        }
    }

    /// Duration string down to the minute, e.g. "1h 30m" or "45m".
    public static func compactDurationString(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// The Health sampling window for a migraine that started at `start`: that calendar
    /// day, capped at `now` when the day is today.
    public static func healthWindow(forStart start: Date, now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let dayStart = calendar.startOfDay(for: start)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? start
        let isToday = calendar.isDate(start, inSameDayAs: now)
        let end = isToday ? min(now, dayEnd) : dayEnd
        return DateInterval(start: dayStart, end: max(dayStart, end))
    }
}
