//
//  MedicationOveruse.swift
//  MygraCore
//
//  Rolling 30-day acute-medication days per class, measured against the ICHD-3
//  medication-overuse thresholds (10 days for triptans, ergots, opioids, and combination
//  analgesics; 15 for simple analgesics) with an "approaching" warning at 8 days. A
//  medication day is a calendar day with at least one dose. Informational only, never
//  medical advice. Pure and host-tested; delivery lives in MygraServices.
//

import Foundation

nonisolated public enum OveruseStatus: Int, Comparable, Codable, Sendable {
    case ok = 0
    case approaching = 1
    case threshold = 2

    public static func < (lhs: OveruseStatus, rhs: OveruseStatus) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Days of use for one class (or, when `medicationClass` is nil, any acute medication).
nonisolated public struct ClassUsage: Equatable, Sendable {
    public let medicationClass: MedicationClass?
    public let days: Int
    public let threshold: Int?
    public let status: OveruseStatus

    public var isOverall: Bool { medicationClass == nil }
}

public struct OveruseAlert: Equatable, Sendable, Identifiable {
    public let usage: ClassUsage
    public var id: String { MedicationOveruse.alertKey(for: usage.medicationClass) }
    public var status: OveruseStatus { usage.status }

    public var title: String {
        let name = usage.medicationClass?.pluralName ?? String(localized: "acute medication")
        switch usage.status {
        case .threshold: return String(localized: "Medication-overuse threshold reached: \(name)")
        default: return String(localized: "Approaching the medication-overuse limit: \(name)")
        }
    }

    public var message: String {
        let days = usage.days
        let limit = usage.threshold ?? MedicationOveruse.overallThresholdDays
        let subject = usage.medicationClass?.pluralName ?? String(localized: "acute medications")
        switch usage.status {
        case .threshold:
            return String(localized: "You've used \(subject) on \(days) of the last 30 days. Using them on \(limit) or more days a month is linked to medication-overuse headache. This is general information, not medical advice. Please talk with your clinician.")
        default:
            return String(localized: "You've used \(subject) on \(days) of the last 30 days, close to the \(limit)-day mark linked to medication-overuse headache. This is general information, not medical advice.")
        }
    }
}

public enum MedicationOveruse {
    public static let windowDays = 30
    public static let approachingDays = 8
    /// Combined limit for several acute-medication classes used together (ICHD-3).
    public static let overallThresholdDays = 10
    /// American Migraine Foundation guidance on medication-overuse headache.
    public static let guidanceURL = URL(string: "https://americanmigrainefoundation.org/resource-library/medication-overuse-headache/")!

    public static func alertKey(for medicationClass: MedicationClass?) -> String {
        medicationClass?.rawValue ?? "overall"
    }

    public static func status(days: Int, threshold: Int?) -> OveruseStatus {
        guard let threshold else { return .ok }
        if days >= threshold { return .threshold }
        if days >= approachingDays { return .approaching }
        return .ok
    }

    /// The rolling window: today plus the 29 days before it.
    public static func window(now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return DateInterval(start: start, end: end)
    }

    /// Distinct calendar days with a dose of `medicationClass` (any class when nil) inside `interval`.
    public static func medicationDays(
        _ doses: [MedicationDose],
        class medicationClass: MedicationClass? = nil,
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> Int {
        var days = Set<Date>()
        for dose in doses where interval.contains(dose.takenAt) {
            if let medicationClass, dose.medicationClass != medicationClass { continue }
            days.insert(calendar.startOfDay(for: dose.takenAt))
        }
        return days.count
    }

    /// Usage for every class with at least one dose in the last 30 days, then the
    /// combined row when two or more limit-bearing classes were used.
    public static func usage(of doses: [MedicationDose], now: Date = Date(), calendar: Calendar = .current) -> [ClassUsage] {
        let interval = window(now: now, calendar: calendar)
        var rows: [ClassUsage] = []
        for medicationClass in MedicationClass.allCases {
            let days = medicationDays(doses, class: medicationClass, in: interval, calendar: calendar)
            guard days > 0 else { continue }
            let threshold = medicationClass.overuseThresholdDays
            rows.append(ClassUsage(medicationClass: medicationClass, days: days, threshold: threshold, status: status(days: days, threshold: threshold)))
        }
        let limited = rows.filter { $0.threshold != nil }
        if limited.count >= 2 {
            let limitedClasses = Set(limited.compactMap(\.medicationClass))
            let limitedDoses = doses.filter { limitedClasses.contains($0.medicationClass) }
            let days = medicationDays(limitedDoses, in: interval, calendar: calendar)
            rows.append(ClassUsage(medicationClass: nil, days: days, threshold: overallThresholdDays, status: status(days: days, threshold: overallThresholdDays)))
        }
        return rows
    }

    /// Every class at or past the approaching mark, worst first.
    public static func alerts(for doses: [MedicationDose], now: Date = Date(), calendar: Calendar = .current) -> [OveruseAlert] {
        usage(of: doses, now: now, calendar: calendar)
            .filter { $0.status > .ok }
            .sorted { ($0.status, $0.days) > ($1.status, $1.days) }
            .map(OveruseAlert.init(usage:))
    }

    /// All doses across the given migraines.
    public static func doses(in migraines: [Migraine]) -> [MedicationDose] {
        migraines.flatMap { $0.medications ?? [] }
    }
}

// MARK: - Notification policy

/// Remembers the level already notified per class so each crossing alerts once. A class
/// that falls back down resets, so the next crossing alerts again.
public struct MedicationAlertLedger {
    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring) { self.defaults = defaults }

    private var levels: [String: Int] {
        get {
            guard let data = defaults.data(forKey: AppStorageKeys.medicationAlertLevels),
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
            return decoded
        }
        nonmutating set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: AppStorageKeys.medicationAlertLevels)
        }
    }

    /// Alerts that moved up since the last call; updates the ledger (including resets).
    public func newAlerts(from usage: [ClassUsage]) -> [OveruseAlert] {
        var stored = levels
        var fresh: [OveruseAlert] = []
        var current: [String: Int] = [:]
        for row in usage where row.status > .ok {
            let key = MedicationOveruse.alertKey(for: row.medicationClass)
            current[key] = row.status.rawValue
            if row.status.rawValue > (stored[key] ?? 0) {
                fresh.append(OveruseAlert(usage: row))
            }
        }
        stored = current
        levels = stored
        return fresh.sorted { ($0.status, $0.usage.days) > ($1.status, $1.usage.days) }
    }
}
