//
//  DateFormatting.swift
//  Mygra
//
//  Created by Nick Molargik on 9/8/25.
//

import Foundation
import SwiftUI

/// Centralized helpers for formatting dates throughout the app,
/// respecting the user's preference for Day–Month–Year vs Month–Day–Year.
enum DateFormatting {

    /// Formats a date as a date-only string using the provided preference.
    /// We intentionally choose a deterministic order instead of relying on
    /// template re-localization, so the app setting overrides locale order.
    static func date(_ value: Date, useDMY: Bool, locale: Locale = .current) -> String {
        let df = DateFormatter()
        df.locale = locale
        // Use localized month name but fixed field order.
        // Examples:
        // - DMY: 28 Aug 2025
        // - MDY: Aug 28, 2025
        if useDMY {
            df.dateFormat = "d MMM yy"
        } else {
            df.dateFormat = "MMM d, yy"
        }
        return df.string(from: value)
    }

    /// Formats a date with time using the provided preference.
    /// Example:
    /// - DMY: 28 Aug 2025, 3:41 PM
    /// - MDY: Aug 28, 2025, 3:41 PM
    static func dateTime(_ value: Date, useDMY: Bool, locale: Locale = .current) -> String {
        let datePart = DateFormatting.date(value, useDMY: useDMY, locale: locale)
        let tOnly = DateFormatter()
        tOnly.locale = locale
        tOnly.timeStyle = .short
        tOnly.dateStyle = .none
        let timePart = tOnly.string(from: value)
        return "\(datePart), \(timePart)"
    }

    /// Formats a date interval with the provided preference.
    /// If both dates are the same calendar day, show: "<date> <startTime>–<endTime>"
    /// Else: "<startDate, time> – <endDate, time>"
    static func dateInterval(
        from startDate: Date,
        to endDate: Date,
        useDMY: Bool,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let sameDay = calendar.isDate(startDate, inSameDayAs: endDate)

        let timeOnly: (Date) -> String = { d in
            let df = DateFormatter()
            df.locale = locale
            df.timeStyle = .short
            df.dateStyle = .none
            return df.string(from: d)
        }

        if sameDay {
            let day = DateFormatting.date(startDate, useDMY: useDMY, locale: locale)
            return "\(day) \(timeOnly(startDate))–\(timeOnly(endDate))"
        } else {
            let a = DateFormatting.dateTime(startDate, useDMY: useDMY, locale: locale)
            let b = DateFormatting.dateTime(endDate, useDMY: useDMY, locale: locale)
            return "\(a) – \(b)"
        }
    }
}
