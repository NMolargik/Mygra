//
//  MigraineReportTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
@testable import MygraCore

@Suite("MigraineReport")
@MainActor
struct MigraineReportTests {
    @Test func emptyReportSaysSo() {
        let blocks = MigraineReport.blocks(user: nil, migraines: [], useMetricUnits: true, useDMY: false)
        #expect(blocks.first == .title("Mygra Export"))
        #expect(blocks.contains(.body("No migraines recorded.")))
        #expect(!blocks.contains(.sectionHeader("User")))
    }

    @Test func reportIncludesUserAndEveryMigraine() {
        let user = User(name: "Nick", chronicConditions: ["Asthma"])
        let first = makeMigraine(start: Date().addingTimeInterval(-7200), end: Date(), pain: 8, triggers: [.stress], foods: ["Coffee"])
        first.isPinned = true
        first.weather = WeatherData(barometricPressureHpa: 1005, temperatureCelsius: 20, humidityPercent: 60, condition: .rain, locationDescription: "Seattle, WA")
        first.health = HealthData(waterLiters: 1.5, sleepHours: 6, caffeineMg: 200, bloodOxygenPercent: 0.97)
        let second = makeMigraine(start: Date().addingTimeInterval(-86_400), end: nil, pain: 3)

        let blocks = MigraineReport.blocks(user: user, migraines: [first, second], useMetricUnits: false, useDMY: false)
        let bodies = blocks.compactMap { block -> String? in
            if case .body(let text) = block { return text }
            return nil
        }
        #expect(bodies.contains("Name: Nick"))
        #expect(bodies.contains("Chronic Conditions: Asthma"))
        #expect(bodies.contains("Pain: 8"))
        #expect(bodies.contains("Triggers: Stress"))
        #expect(bodies.contains("Foods: Coffee"))
        #expect(bodies.contains { $0.hasPrefix("Weather: Condition: Rain") && $0.contains("Seattle, WA") && $0.contains("inHg") })
        #expect(bodies.contains { $0.hasPrefix("Health:") && $0.contains("51 fl oz") && $0.contains("O2: 97%") })
        #expect(bodies.contains("Ongoing"))
        #expect(blocks.filter { $0 == .divider }.count == 1)
        #expect(blocks.contains { if case .subheadline(let text) = $0 { return text.contains("[Pinned]") } else { return false } })
    }
}

@Suite("MigraineReport CSV")
@MainActor
struct MigraineReportCSVTests {
    @Test("the header row matches the column list and every row has the same width")
    func shape() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let migraine = makeMigraine(start: start, end: start.addingTimeInterval(5_400), pain: 7, stress: 4, note: "Said \"ouch\", then slept", triggers: [.stress], customTriggers: ["Screen glare"], foods: ["Cheese", "Wine"])
        let csv = MigraineReport.csv(migraines: [migraine, makeMigraine(start: start.addingTimeInterval(-86_400))], useMetricUnits: true)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == MigraineReport.csvHeaders.joined(separator: ","))
        #expect(lines[1].hasPrefix("2023-11-14T22:13:20Z,2023-11-14T23:43:20Z,false,90,7,4,"))
        // Newest first; the quoted note keeps its embedded quotes doubled.
        #expect(lines[1].contains("\"Said \"\"ouch\"\", then slept\""))
        #expect(lines[1].contains("stress"))
        #expect(lines[1].contains("Cheese; Wine"))
        #expect(lines[2].contains(",true,,"))
    }

    @Test("fields with commas, quotes, or newlines are quoted; others are left bare")
    func quoting() {
        #expect(MigraineReport.csvLine(["a", "b c", "1.5"]) == "a,b c,1.5")
        #expect(MigraineReport.csvLine(["x, y"]) == "\"x, y\"")
        #expect(MigraineReport.csvLine(["say \"hi\""]) == "\"say \"\"hi\"\"\"")
        #expect(MigraineReport.csvLine(["two\nlines"]) == "\"two\nlines\"")
    }

    @Test("units follow the preference")
    func units() {
        let migraine = makeMigraine()
        let weather = WeatherData(barometricPressureHpa: 1013, temperatureCelsius: 20, humidityPercent: 55, condition: .clear)
        migraine.weather = weather
        let metric = MigraineReport.csvRow(for: migraine, useMetricUnits: true, formatter: ISO8601DateFormatter())
        let imperial = MigraineReport.csvRow(for: migraine, useMetricUnits: false, formatter: ISO8601DateFormatter())
        let temperatureIndex = MigraineReport.csvHeaders.firstIndex(of: "Temperature")!
        let pressureIndex = MigraineReport.csvHeaders.firstIndex(of: "Pressure")!
        #expect(metric[temperatureIndex] == "20.0")
        #expect(imperial[temperatureIndex] == "68.0")
        #expect(metric[pressureIndex] == "1013")
        #expect(imperial[pressureIndex].hasPrefix("29.9"))
    }
}
