//
//  DateFormatting.swift
//  MygraCore
//
//  Date formatting that respects the user's Day–Month–Year vs Month–Day–Year preference.
//  A deterministic field order is chosen deliberately so the app setting overrides the
//  locale's order.
//

import Foundation

nonisolated public enum DateFormatting {
    /// Date-only, e.g. "28 Aug 2025" (DMY) or "Aug 28, 2025".
    public static func date(_ value: Date, useDMY: Bool, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = useDMY ? "d MMM yyyy" : "MMM d, yyyy"
        return formatter.string(from: value)
    }

    /// Date with time, e.g. "28 Aug 2025, 3:41 PM" (DMY) or "Aug 28, 2025, 3:41 PM".
    public static func dateTime(_ value: Date, useDMY: Bool, locale: Locale = .current) -> String {
        "\(date(value, useDMY: useDMY, locale: locale)), \(time(value, locale: locale))"
    }

    /// Compact date with time, e.g. "1/1/26, 1:23 PM".
    public static func compactDateTime(_ value: Date, useDMY: Bool, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = useDMY ? "d/M/yy, h:mm a" : "M/d/yy, h:mm a"
        return formatter.string(from: value)
    }

    /// Short time only, e.g. "3:41 PM".
    public static func time(_ value: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: value)
    }

    /// A date interval. Same-day: "<date> <start>–<end>"; otherwise "<start date, time> – <end date, time>".
    public static func dateInterval(
        from startDate: Date,
        to endDate: Date,
        useDMY: Bool,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            let day = date(startDate, useDMY: useDMY, locale: locale)
            return "\(day) \(time(startDate, locale: locale))–\(time(endDate, locale: locale))"
        }
        return "\(dateTime(startDate, useDMY: useDMY, locale: locale)) – \(dateTime(endDate, useDMY: useDMY, locale: locale))"
    }
}
