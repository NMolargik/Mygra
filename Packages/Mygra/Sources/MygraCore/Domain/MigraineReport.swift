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
