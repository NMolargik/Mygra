//
//  ClinicalReport.swift
//  MygraCore
//
//  The clinic-facing report, built on `MigraineReport`'s blocks: headache and migraine
//  days per month, acute-medication days by class against the 10/15-day thresholds,
//  MIDAS and HIT-6 scores, a trigger/tag frequency table, one pain curve per attack,
//  then the existing per-attack detail. Patient-identifying fields are opt-in.
//
//  Definitions (printed in the report): a headache day is a calendar day touched by an
//  attack; a migraine day is a headache day with an attack that peaked at pain 4+ or ran
//  4+ hours (ICHD-3 migraine attacks last 4-72 hours).
//

import Foundation

nonisolated public struct ClinicalReportOptions: Equatable, Sendable {
    /// 1, 3, or 6.
    public var months: Int
    public var includeName: Bool
    public var includeBirthday: Bool
    /// Sex, height, weight, sleep, caffeine, conditions, diet.
    public var includeHealthProfile: Bool

    public static let allowedMonths = [1, 3, 6]

    public init(months: Int = 3, includeName: Bool = true, includeBirthday: Bool = false, includeHealthProfile: Bool = true) {
        self.months = Self.allowedMonths.contains(months) ? months : 3
        self.includeName = includeName
        self.includeBirthday = includeBirthday
        self.includeHealthProfile = includeHealthProfile
    }
}

/// Headache/migraine days within one calendar month of the report window.
nonisolated public struct MonthlyDayCounts: Equatable, Sendable {
    public let monthStart: Date
    public let headacheDays: Int
    public let migraineDays: Int
}

public enum ClinicalReport {

    // MARK: - Day math

    /// The report window: from `months` calendar months ago (start of that day) through `now`.
    public static func window(months: Int, now: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(byAdding: .month, value: -months, to: calendar.startOfDay(for: now)) ?? now
        return DateInterval(start: start, end: max(now, start))
    }

    static func peakPain(_ migraine: Migraine) -> Int {
        max(migraine.painLevel, (migraine.intensitySamples ?? []).map(\.painLevel).max() ?? 0)
    }

    public static func isMigraineLevel(_ migraine: Migraine, now: Date) -> Bool {
        let end = migraine.endDate ?? now
        return peakPain(migraine) >= 4 || end.timeIntervalSince(migraine.startDate) >= 4 * 3600
    }

    /// Calendar days an attack touches, clipped to `interval`.
    static func days(of migraine: Migraine, in interval: DateInterval, now: Date, calendar: Calendar) -> [Date] {
        let first = calendar.startOfDay(for: max(migraine.startDate, interval.start))
        let lastMoment = min(migraine.endDate ?? now, interval.end)
        let last = calendar.startOfDay(for: max(lastMoment, migraine.startDate))
        guard migraine.startDate <= interval.end, last >= first else { return [] }
        var result: [Date] = []
        var day = first
        while day <= last {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    public static func headacheDays(_ migraines: [Migraine], in interval: DateInterval, now: Date, calendar: Calendar = .current) -> Set<Date> {
        Set(migraines.flatMap { days(of: $0, in: interval, now: now, calendar: calendar) })
    }

    public static func migraineDays(_ migraines: [Migraine], in interval: DateInterval, now: Date, calendar: Calendar = .current) -> Set<Date> {
        Set(migraines.filter { isMigraineLevel($0, now: now) }.flatMap { days(of: $0, in: interval, now: now, calendar: calendar) })
    }

    /// Calendar months overlapping the window, oldest first.
    static func monthStarts(in interval: DateInterval, calendar: Calendar) -> [Date] {
        guard var cursor = calendar.dateInterval(of: .month, for: interval.start)?.start else { return [] }
        var months: [Date] = []
        while cursor < interval.end {
            months.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }

    static func monthInterval(_ monthStart: Date, clippedTo window: DateInterval, calendar: Calendar) -> DateInterval {
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let start = max(monthStart, window.start)
        return DateInterval(start: start, end: max(min(monthEnd, window.end), start))
    }

    public static func monthlyCounts(_ migraines: [Migraine], window: DateInterval, now: Date, calendar: Calendar = .current) -> [MonthlyDayCounts] {
        monthStarts(in: window, calendar: calendar).map { month in
            let slice = monthInterval(month, clippedTo: window, calendar: calendar)
            return MonthlyDayCounts(
                monthStart: month,
                headacheDays: headacheDays(migraines, in: slice, now: now, calendar: calendar).count,
                migraineDays: migraineDays(migraines, in: slice, now: now, calendar: calendar).count
            )
        }
    }

    // MARK: - Report

    public static func blocks(
        user: User?,
        migraines allMigraines: [Migraine],
        options: ClinicalReportOptions = ClinicalReportOptions(),
        assessment: ClinicalAssessment = ClinicalAssessment(),
        useMetricUnits: Bool,
        useDMY: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReportBlock] {
        let window = window(months: options.months, now: now, calendar: calendar)
        let migraines = allMigraines
            .filter { $0.startDate <= window.end && ($0.endDate ?? now) >= window.start }
            .sorted { $0.startDate > $1.startDate }
        let doses = MedicationOveruse.doses(in: allMigraines)
        var blocks: [ReportBlock] = []

        blocks.append(.title(String(localized: "Mygra Clinical Report")))
        blocks.append(.spacer(6))
        blocks.append(.subheadline(String(localized: "Period: \(DateFormatting.dateInterval(from: window.start, to: window.end, useDMY: useDMY)) (\(options.months) \(options.months == 1 ? String(localized: "month") : String(localized: "months")))")))
        blocks.append(.body(String(localized: "Exported \(DateFormatting.dateTime(now, useDMY: useDMY))")))
        blocks.append(.spacer(12))

        blocks += patientBlocks(user: user, options: options, useMetricUnits: useMetricUnits, useDMY: useDMY)
        blocks += summaryBlocks(migraines: migraines, window: window, now: now, calendar: calendar)
        blocks += medicationBlocks(doses: doses, window: window, now: now, calendar: calendar)
        blocks += assessmentBlocks(assessment, useDMY: useDMY)
        blocks += frequencyBlocks(migraines: migraines)
        blocks += curveBlocks(migraines: migraines, now: now, useDMY: useDMY)

        blocks.append(.sectionHeader(String(localized: "Attack Detail (\(migraines.count))")))
        blocks.append(.spacer(6))
        if migraines.isEmpty {
            blocks.append(.body(String(localized: "No migraines recorded in this period.")))
        }
        for (index, migraine) in migraines.enumerated() {
            blocks.append(.subheadline(MigraineReport.headline(for: migraine, useDMY: useDMY)))
            for line in MigraineReport.detailLines(for: migraine, useMetricUnits: useMetricUnits, useDMY: useDMY) {
                blocks.append(.body(line))
            }
            blocks.append(.spacer(12))
            if index < migraines.count - 1 { blocks.append(.divider) }
        }

        blocks.append(.spacer(8))
        blocks.append(.divider)
        blocks.append(.body(String(localized: "Generated from patient-entered data in Mygra. This report is informational, is not a diagnosis, and is not medical advice. Questionnaire scores are screening aids. Medication-overuse thresholds follow ICHD-3.")))
        return blocks
    }

    // MARK: - Sections

    static func patientBlocks(user: User?, options: ClinicalReportOptions, useMetricUnits: Bool, useDMY: Bool) -> [ReportBlock] {
        guard let user else { return [] }
        var lines: [String] = []
        if options.includeName, !user.name.isEmpty { lines.append(String(localized: "Name: \(user.name)")) }
        if options.includeBirthday { lines.append(String(localized: "Birthday: \(DateFormatting.date(user.birthday, useDMY: useDMY))")) }
        if options.includeHealthProfile {
            // `userLines` leads with name and birthday, which are opt-in on their own.
            lines += Array(MigraineReport.userLines(user, useMetricUnits: useMetricUnits, useDMY: useDMY).dropFirst(2))
        }
        guard !lines.isEmpty else { return [] }
        return [.sectionHeader(String(localized: "Patient")), .spacer(6)] + lines.map { .body($0) } + [.spacer(12)]
    }

    static func summaryBlocks(migraines: [Migraine], window: DateInterval, now: Date, calendar: Calendar) -> [ReportBlock] {
        let counts = monthlyCounts(migraines, window: window, now: now, calendar: calendar)
        let headache = headacheDays(migraines, in: window, now: now, calendar: calendar).count
        let migraine = migraineDays(migraines, in: window, now: now, calendar: calendar).count
        let spanDays = max(1, calendar.dateComponents([.day], from: window.start, to: window.end).day ?? 30)
        let perMonth = { (value: Int) in Double(value) * 30.0 / Double(spanDays) }
        let monthFormat = Date.FormatStyle().month(.abbreviated).year()
        var rows = counts.map { [$0.monthStart.formatted(monthFormat), String($0.headacheDays), String($0.migraineDays)] }
        rows.append([String(localized: "Total"), String(headache), String(migraine)])
        rows.append([String(localized: "Average per 30 days"), String(format: "%.1f", perMonth(headache)), String(format: "%.1f", perMonth(migraine))])

        let pains = migraines.map(peakPain)
        var blocks: [ReportBlock] = [
            .sectionHeader(String(localized: "Headache and Migraine Days")),
            .spacer(6),
            .table(ReportTable(
                columns: [String(localized: "Month"), String(localized: "Headache days"), String(localized: "Migraine days")],
                rows: rows,
                highlightedRows: [rows.count - 2, rows.count - 1]
            )),
            .spacer(4),
            .body(String(localized: "Attacks: \(migraines.count)")),
        ]
        if !pains.isEmpty {
            blocks.append(.body(String(format: String(localized: "Average peak pain: %.1f / 10"), Double(pains.reduce(0, +)) / Double(pains.count))))
        }
        blocks.append(.body(String(localized: "A headache day is any calendar day touched by an attack. A migraine day is a headache day with an attack that peaked at pain 4 or higher or lasted 4 hours or more.")))
        blocks.append(.spacer(12))
        return blocks
    }

    static func medicationBlocks(doses: [MedicationDose], window: DateInterval, now: Date, calendar: Calendar) -> [ReportBlock] {
        var blocks: [ReportBlock] = [.sectionHeader(String(localized: "Acute Medication Days")), .spacer(6)]
        let usedClasses = MedicationClass.allCases.filter { cls in doses.contains { $0.medicationClass == cls && window.contains($0.takenAt) } }
        guard !usedClasses.isEmpty else {
            blocks.append(.body(String(localized: "No acute medication recorded in this period.")))
            blocks.append(.spacer(12))
            return blocks
        }
        let months = monthStarts(in: window, calendar: calendar)
        let monthFormat = Date.FormatStyle().month(.abbreviated)
        let rolling = MedicationOveruse.window(now: now, calendar: calendar)
        var rows: [[String]] = []
        var highlighted = Set<Int>()
        for cls in usedClasses {
            var row = [cls.displayName]
            var flagged = false
            for month in months {
                let slice = monthInterval(month, clippedTo: window, calendar: calendar)
                let days = MedicationOveruse.medicationDays(doses, class: cls, in: slice, calendar: calendar)
                row.append(String(days))
                if let limit = cls.overuseThresholdDays, days >= limit { flagged = true }
            }
            let last30 = MedicationOveruse.medicationDays(doses, class: cls, in: rolling, calendar: calendar)
            if let limit = cls.overuseThresholdDays, last30 >= limit { flagged = true }
            row.append(String(last30))
            row.append(cls.overuseThresholdDays.map { String(localized: "\($0)+ days") } ?? "—")
            if flagged { row[0] += " ⚠"; highlighted.insert(rows.count) }
            rows.append(row)
        }
        let columns = [String(localized: "Class")] + months.map { $0.formatted(monthFormat) } + [String(localized: "Last 30 d"), String(localized: "Limit")]
        blocks.append(.table(ReportTable(columns: columns, rows: rows, highlightedRows: highlighted)))
        blocks.append(.spacer(4))
        blocks.append(.body(String(localized: "Days with at least one dose. Limits: ergots, triptans, opioids, and combination analgesics 10 or more days a month; simple analgesics 15 or more. ⚠ marks a month or the last 30 days at or past the limit.")))
        let names = Set(doses.filter { window.contains($0.takenAt) }.map(\.name)).sorted()
        if !names.isEmpty {
            blocks.append(.body(String(localized: "Medications recorded: \(names.joined(separator: ", "))")))
        }
        blocks.append(.spacer(12))
        return blocks
    }

    static func assessmentBlocks(_ assessment: ClinicalAssessment, useDMY: Bool) -> [ReportBlock] {
        var blocks: [ReportBlock] = [.sectionHeader(String(localized: "Questionnaires")), .spacer(6)]
        if let score = assessment.midasScore {
            let date = assessment.midasDate.map { " (\(DateFormatting.date($0, useDMY: useDMY)))" } ?? ""
            blocks.append(.body(String(localized: "MIDAS: \(score) days lost, \(MIDAS.grade(forScore: score).label)\(date)")))
        } else {
            blocks.append(.body(String(localized: "MIDAS: not completed")))
        }
        if let score = assessment.hit6Score {
            let date = assessment.hit6Date.map { " (\(DateFormatting.date($0, useDMY: useDMY)))" } ?? ""
            blocks.append(.body(String(localized: "HIT-6: \(score) of 78, \(HIT6.band(forScore: score).label)\(date)")))
        } else {
            blocks.append(.body(String(localized: "HIT-6: not completed")))
        }
        blocks.append(.spacer(12))
        return blocks
    }

    static func frequencyBlocks(migraines: [Migraine], limit: Int = 15) -> [ReportBlock] {
        guard !migraines.isEmpty else { return [] }
        var triggerCounts: [String: (name: String, count: Int)] = [:]
        var tagCounts: [String: (name: String, count: Int)] = [:]
        for migraine in migraines {
            for name in migraine.allTriggerNames {
                triggerCounts[name.lowercased(), default: (name, 0)].count += 1
            }
            for name in Set((migraine.tags ?? []).map(\.name)).filter({ !$0.isEmpty }) {
                tagCounts[name.lowercased(), default: (name, 0)].count += 1
            }
        }
        func table(_ counts: [String: (name: String, count: Int)], header: String) -> ReportBlock {
            let rows = counts.values
                .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
                .prefix(limit)
                .map { [$0.name, String($0.count), String(format: "%.0f%%", Double($0.count) * 100 / Double(migraines.count))] }
            return .table(ReportTable(columns: [header, String(localized: "Attacks"), String(localized: "% of attacks")], rows: Array(rows)))
        }
        var blocks: [ReportBlock] = []
        if !triggerCounts.isEmpty {
            blocks += [.sectionHeader(String(localized: "Trigger Frequency")), .spacer(6), table(triggerCounts, header: String(localized: "Trigger")), .spacer(12)]
        }
        if !tagCounts.isEmpty {
            blocks += [.sectionHeader(String(localized: "Tag Frequency")), .spacer(6), table(tagCounts, header: String(localized: "Tag")), .spacer(12)]
        }
        return blocks
    }

    static func curveBlocks(migraines: [Migraine], now: Date, useDMY: Bool) -> [ReportBlock] {
        guard !migraines.isEmpty else { return [] }
        var blocks: [ReportBlock] = [.sectionHeader(String(localized: "Intensity Over Time")), .spacer(6)]
        for migraine in migraines.sorted(by: { $0.startDate > $1.startDate }) {
            var samples = migraine.sortedIntensitySamples
            if samples.isEmpty {
                samples = [IntensitySample(timestamp: migraine.startDate, painLevel: migraine.painLevel, stressLevel: migraine.stressLevel)]
            }
            let points = samples.map {
                ReportCurve.Point(minutes: max(0, $0.timestamp.timeIntervalSince(migraine.startDate) / 60), pain: Double($0.painLevel))
            }
            let end = migraine.endDate ?? now
            let subtitle = String(localized: "Duration \(MigraineDates.durationString(end.timeIntervalSince(migraine.startDate))), peak pain \(peakPain(migraine))")
            blocks.append(.curve(ReportCurve(title: DateFormatting.dateTime(migraine.startDate, useDMY: useDMY), subtitle: subtitle, points: points)))
        }
        blocks.append(.spacer(12))
        return blocks
    }
}
