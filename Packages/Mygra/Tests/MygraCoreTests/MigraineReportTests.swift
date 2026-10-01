//
//  MigraineReportTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

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
