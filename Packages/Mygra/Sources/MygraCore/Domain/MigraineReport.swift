//
//  MigraineReport.swift
//  MygraCore
//
//  The exported migraine report as pure layout blocks. Building the text is host-tested
//  here; drawing it into a PDF is a MygraServices concern (UIKit).
//

import Foundation

nonisolated public enum ReportBlock: Equatable, Sendable {
    case title(String)
    case sectionHeader(String)
    case subheadline(String)
    case body(String)
    case spacer(CGFloat)
    case divider
    case table(ReportTable)
    case curve(ReportCurve)
}

/// A simple grid: header row plus rows; `highlightedRows` are drawn emphasized (thresholds).
nonisolated public struct ReportTable: Equatable, Sendable {
    public var columns: [String]
    public var rows: [[String]]
    public var highlightedRows: Set<Int>

    public init(columns: [String], rows: [[String]], highlightedRows: Set<Int> = []) {
        self.columns = columns
        self.rows = rows
        self.highlightedRows = highlightedRows
    }
}

/// One attack's pain over time (x = minutes since onset, y = pain 0...10).
nonisolated public struct ReportCurve: Equatable, Sendable {
    public struct Point: Equatable, Sendable {
        public let minutes: Double
        public let pain: Double
        public init(minutes: Double, pain: Double) {
            self.minutes = minutes
            self.pain = pain
        }
    }

    public var title: String
    public var subtitle: String
    public var points: [Point]

    public init(title: String, subtitle: String, points: [Point]) {
        self.title = title
        self.subtitle = subtitle
        self.points = points
    }
}

public enum MigraineReport {
    /// Lays out the whole export: header, user profile, then one block group per migraine.
    public static func blocks(
        user: User?,
        migraines: [Migraine],
        useMetricUnits: Bool,
        useDMY: Bool,
        now: Date = Date()
    ) -> [ReportBlock] {
        var blocks: [ReportBlock] = []

        blocks.append(.title(String(localized: "Mygra Export")))
        blocks.append(.spacer(8))
        blocks.append(.subheadline(String(localized: "Exported \(DateFormatting.dateTime(now, useDMY: useDMY))")))
        blocks.append(.spacer(16))

        if let user {
            blocks.append(.sectionHeader(String(localized: "User")))
            blocks.append(.spacer(6))
            for line in userLines(user, useMetricUnits: useMetricUnits, useDMY: useDMY) {
                blocks.append(.body(line))
            }
            blocks.append(.spacer(12))
        }

        blocks.append(.sectionHeader(String(localized: "Migraines (\(migraines.count))")))
        blocks.append(.spacer(6))

        if migraines.isEmpty {
            blocks.append(.body(String(localized: "No migraines recorded.")))
            return blocks
        }

        for (index, migraine) in migraines.enumerated() {
            blocks.append(.subheadline(headline(for: migraine, useDMY: useDMY)))
            for line in detailLines(for: migraine, useMetricUnits: useMetricUnits, useDMY: useDMY) {
                blocks.append(.body(line))
            }
            blocks.append(.spacer(12))
            if index < migraines.count - 1 {
                blocks.append(.divider)
            }
        }
        return blocks
    }

    // MARK: - Sections

    static func userLines(_ user: User, useMetricUnits: Bool, useDMY: Bool) -> [String] {
        let heightUnit = useMetricUnits ? "cm" : "in"
        let weightUnit = useMetricUnits ? "kg" : "lb"
        let dash = "—"
        return [
            String(localized: "Name: \(user.name.isEmpty ? dash : user.name)"),
            String(localized: "Birthday: \(DateFormatting.date(user.birthday, useDMY: useDMY))"),
            String(localized: "Biological Sex: \(user.biologicalSex.displayName)"),
            String(format: String(localized: "Height: %.1f %@"), user.displayHeight(useMetricUnits: useMetricUnits), heightUnit),
            String(format: String(localized: "Weight: %.1f %@"), user.displayWeight(useMetricUnits: useMetricUnits), weightUnit),
            String(format: String(localized: "Avg Sleep: %.1f h"), user.averageSleepHours),
            String(format: String(localized: "Avg Caffeine: %.0f mg"), user.averageCaffeineMg),
            String(localized: "Chronic Conditions: \(user.chronicConditions.isEmpty ? dash : user.chronicConditions.joined(separator: ", "))"),
            String(localized: "Dietary Restrictions: \(user.dietaryRestrictions.isEmpty ? dash : user.dietaryRestrictions.joined(separator: ", "))"),
        ]
    }

    static func headline(for migraine: Migraine, useDMY: Bool) -> String {
        let pinned = migraine.isPinned ? "  [\(String(localized: "Pinned"))]" : ""
        return "• \(DateFormatting.dateTime(migraine.startDate, useDMY: useDMY))\(pinned)"
    }

    static func detailLines(for migraine: Migraine, useMetricUnits: Bool, useDMY: Bool) -> [String] {
        var lines: [String] = []

        if let end = migraine.endDate {
            lines.append(String(localized: "Range: \(DateFormatting.dateInterval(from: migraine.startDate, to: end, useDMY: useDMY))"))
            lines.append(String(localized: "Duration: \(MigraineDates.durationString(end.timeIntervalSince(migraine.startDate)))"))
        } else {
            lines.append(String(localized: "Ongoing"))
        }
        lines.append(String(localized: "Pain: \(migraine.painLevel)"))
        lines.append(String(localized: "Stress: \(migraine.stressLevel)"))

        if !migraine.sortedMedications.isEmpty {
            let doses = migraine.sortedMedications.map { "\($0.summary) (\($0.medicationClass.displayName), \(DateFormatting.time($0.takenAt)))" }
            lines.append(String(localized: "Medications: \(doses.joined(separator: "; "))"))
        }
        if !migraine.triggers.isEmpty {
            lines.append(String(localized: "Triggers: \(migraine.triggers.map(\.displayName).joined(separator: ", "))"))
        }
        if !migraine.customTriggers.isEmpty {
            lines.append(String(localized: "Custom Triggers: \(migraine.customTriggers.joined(separator: ", "))"))
        }
        if !migraine.foodsEaten.isEmpty {
            lines.append(String(localized: "Foods: \(migraine.foodsEaten.joined(separator: ", "))"))
        }
        if let note = migraine.note, !note.isEmpty {
            lines.append(String(localized: "Note: \(note)"))
        }
        if let weather = migraine.weather {
            lines.append(String(localized: "Weather: \(weatherSummary(weather, useMetricUnits: useMetricUnits))"))
        }
        if let health = migraine.health {
            let summary = healthSummary(health, useMetricUnits: useMetricUnits)
            if !summary.isEmpty {
                lines.append(String(localized: "Health: \(summary)"))
            }
        }
        return lines
    }

    static func weatherSummary(_ weather: WeatherData, useMetricUnits: Bool) -> String {
        var parts: [String] = []
        parts.append(String(localized: "Condition: \(weather.condition.displayName)"))
        let temp = weather.displayTemperature(useMetricUnits: useMetricUnits)
        parts.append(String(format: String(localized: "Temp: %.0f%@"), temp, useMetricUnits ? "°C" : "°F"))
        parts.append(String(localized: "Humidity: \(Int(weather.humidityPercent))%"))
        let pressure = weather.displayBarometricPressure(useMetricUnits: useMetricUnits)
        if useMetricUnits {
            parts.append(String(format: String(localized: "Pressure: %.0f hPa"), pressure))
        } else {
            parts.append(String(format: String(localized: "Pressure: %.2f inHg"), pressure))
        }
        if let place = weather.locationDescription, !place.isEmpty {
            parts.append(String(localized: "Location: \(place)"))
        }
        return parts.joined(separator: ", ")
    }

    static func healthSummary(_ health: HealthData, useMetricUnits: Bool) -> String {
        var parts: [String] = []
        if let liters = health.waterLiters {
            if useMetricUnits {
                parts.append(String(format: String(localized: "Water: %.1f L"), liters))
            } else {
                parts.append(String(format: String(localized: "Water: %.0f fl oz"), liters * UnitConversion.litersToFluidOunces))
            }
        }
        if let hours = health.sleepHours {
            parts.append(String(format: String(localized: "Sleep: %.1f h"), hours))
        }
        if let kcal = health.energyKilocalories {
            parts.append(String(format: String(localized: "Food: %.0f cal (kcal)"), kcal))
        }
        if let caffeine = health.caffeineMg {
            parts.append(String(format: String(localized: "Caffeine: %.0f mg"), caffeine))
        }
        if let steps = health.stepCount {
            parts.append(String(localized: "Steps: \(steps)"))
        }
        if let rhr = health.restingHeartRate {
            parts.append(String(localized: "Resting HR: \(rhr) bpm"))
        }
        if let ahr = health.activeHeartRate {
            parts.append(String(localized: "Active HR: \(ahr) bpm"))
        }
        if let phase = health.menstrualPhase {
            parts.append(String(localized: "Menstrual Phase: \(phase.displayName)"))
        }
        if let glucose = health.glucoseMgPerdL {
            if useMetricUnits {
                parts.append(String(format: String(localized: "Glucose: %.1f mmol/L"), glucose / UnitConversion.glucoseMgDlToMmolL))
            } else {
                parts.append(String(format: String(localized: "Glucose: %.0f mg/dL"), glucose.rounded()))
            }
        }
        if let spo2 = health.bloodOxygenPercent {
            let percent = spo2 * 100.0
            if percent.truncatingRemainder(dividingBy: 1) == 0 {
                parts.append(String(localized: "O2: \(Int(percent))%"))
            } else {
                parts.append(String(format: String(localized: "O2: %.1f%%"), percent))
            }
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - CSV

extension MigraineReport {
    /// Column headers for the raw CSV export. English and stable on purpose: the file is
    /// meant for spreadsheets and other tools, not for reading in the app.
    public static let csvHeaders: [String] = [
        "Start", "End", "Ongoing", "Duration (minutes)", "Pain (0-10)", "Stress (0-10)", "Severity", "Pinned",
        "Triggers", "Custom Triggers", "Foods", "Tags", "Medications", "Note",
        "Weather Condition", "Temperature", "Humidity (%)", "Pressure", "Weather Location",
        "Water", "Sleep (h)", "Food (kcal)", "Caffeine (mg)", "Steps", "Resting HR (bpm)", "Active HR (bpm)",
        "Glucose", "Blood Oxygen (%)", "Menstrual Phase", "Insight",
    ]

    /// One row per migraine, newest first, with ISO 8601 timestamps and the user's units.
    public static func csv(migraines: [Migraine], useMetricUnits: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [csvLine(csvHeaders)]
        for migraine in migraines.sorted(by: { $0.startDate > $1.startDate }) {
            lines.append(csvLine(csvRow(for: migraine, useMetricUnits: useMetricUnits, formatter: formatter)))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func csvRow(for migraine: Migraine, useMetricUnits: Bool, formatter: ISO8601DateFormatter) -> [String] {
        let dash = ""
        let weather = migraine.weather
        let health = migraine.health
        func number(_ value: Double?, precision: Int = 1) -> String {
            guard let value else { return dash }
            return String(format: "%.\(precision)f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        func integer(_ value: Int?) -> String { value.map(String.init) ?? dash }

        let temperature = weather.map { useMetricUnits ? $0.temperatureCelsius : $0.temperatureFahrenheit }
        let pressure = weather.map { useMetricUnits ? $0.barometricPressureHpa : $0.barometricPressureInHg }
        let water = health?.waterLiters.map { useMetricUnits ? $0 : $0 * UnitConversion.litersToFluidOunces }
        let glucose = health?.glucoseMgPerdL.map { useMetricUnits ? $0 / UnitConversion.glucoseMgDlToMmolL : $0 }

        return [
            formatter.string(from: migraine.startDate),
            migraine.endDate.map(formatter.string(from:)) ?? dash,
            migraine.isOngoing ? "true" : "false",
            migraine.duration.map { String(Int(($0 / 60).rounded())) } ?? dash,
            String(migraine.painLevel),
            String(migraine.stressLevel),
            migraine.severity.rawValue,
            migraine.isPinned ? "true" : "false",
            migraine.triggers.map(\.rawValue).joined(separator: "; "),
            migraine.customTriggers.joined(separator: "; "),
            migraine.foodsEaten.joined(separator: "; "),
            (migraine.tags ?? []).map(\.name).sorted().joined(separator: "; "),
            migraine.sortedMedications.map { "\($0.name)\($0.dose.isEmpty ? "" : " " + $0.dose) [\($0.medicationClass.rawValue)] @ \(formatter.string(from: $0.takenAt))" }.joined(separator: "; "),
            migraine.note ?? dash,
            weather?.condition.rawValue ?? dash,
            number(temperature),
            weather.map { number($0.humidityPercent, precision: 0) } ?? dash,
            number(pressure, precision: useMetricUnits ? 0 : 2),
            weather?.locationDescription ?? dash,
            number(water, precision: useMetricUnits ? 2 : 0),
            number(health?.sleepHours),
            number(health?.energyKilocalories, precision: 0),
            number(health?.caffeineMg, precision: 0),
            integer(health?.stepCount),
            integer(health?.restingHeartRate),
            integer(health?.activeHeartRate),
            number(glucose, precision: useMetricUnits ? 1 : 0),
            health?.bloodOxygenPercent.map { number($0 * 100, precision: 1) } ?? dash,
            health?.menstrualPhase?.rawValue ?? dash,
            migraine.insight ?? dash,
        ]
    }

    /// RFC 4180 quoting: fields containing commas, quotes, or newlines are wrapped in
    /// double quotes with embedded quotes doubled.
    static func csvLine(_ fields: [String]) -> String {
        fields.map { field in
            guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",")
    }
}
