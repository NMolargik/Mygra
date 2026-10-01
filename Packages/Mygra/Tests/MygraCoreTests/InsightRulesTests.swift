//
//  InsightRulesTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("InsightRules")
@MainActor
struct InsightRulesTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private let calendar = Calendar(identifier: .gregorian)

    @Test func emptyInputYieldsNoInsights() {
        #expect(InsightRules.generateAll(from: [], now: now, calendar: calendar).isEmpty)
    }

    @Test func risingFrequencyIsHighPriority() throws {
        var items = [2, 5, 9].map { makeMigraine(start: now.addingTimeInterval(Double(-$0) * 86_400)) }
        items.append(makeMigraine(start: now.addingTimeInterval(-20 * 86_400)))

        let trends = InsightRules.trends(items, now: now, calendar: calendar)
        let frequency = try #require(trends.first { $0.category == .trendFrequency })
        #expect(frequency.priority == .high)
        #expect(frequency.title.contains("increased"))
    }

    @Test func commonTriggerSurfacesWithPercentage() throws {
        let items = (0..<4).map { i in
            makeMigraine(start: now.addingTimeInterval(Double(-i) * 86_400), triggers: i < 3 ? [.stress] : [])
        }
        let insights = InsightRules.triggers(items)
        let stress = try #require(insights.first { $0.title.contains("Stress") })
        #expect(stress.priority == .high)
        #expect(stress.message.contains("75%"))
    }

    @Test func customTriggersAreGroupedCaseInsensitively() throws {
        let items = [
            makeMigraine(start: now, customTriggers: ["red wine"]),
            makeMigraine(start: now, customTriggers: ["Red Wine"]),
        ]
        let insights = InsightRules.triggers(items)
        let wine = try #require(insights.first { $0.title.contains("Red Wine") })
        #expect(wine.message.contains("100%"))
    }

    @Test func sleepRuleNeedsFiveSamplesAndOnePointGap() {
        func attach(_ sleep: Double, pain: Int) -> Migraine {
            let migraine = makeMigraine(start: now, pain: pain)
            migraine.health = HealthData(sleepHours: sleep)
            return migraine
        }
        var items = [attach(5, pain: 8), attach(6, pain: 9), attach(5.5, pain: 8), attach(8, pain: 3), attach(9, pain: 2)]
        let insights = InsightRules.sleep(items)
        #expect(insights.count == 1)
        #expect(insights.first?.category == .sleepAssociation)

        items.removeLast()
        #expect(InsightRules.sleep(items).isEmpty)
    }

    @Test func lowHydrationInsightExposesLiters() throws {
        let migraine = makeMigraine(start: now.addingTimeInterval(-3600))
        migraine.health = HealthData(waterLiters: 0.8)
        let insight = try #require(InsightRules.intake([migraine], now: now, calendar: calendar).first { $0.category == .intakeHydration })
        #expect(insight.doubleTag("avgLiters") == 0.8)
        #expect(insight.priority == .high)
    }

    @Test func weatherRuleFlagsLowPressure() throws {
        func withWeather(pressure: Double, pain: Int) -> Migraine {
            let migraine = makeMigraine(start: now, pain: pain)
            migraine.weather = WeatherData(barometricPressureHpa: pressure, temperatureCelsius: 20, humidityPercent: 50, condition: .clear)
            return migraine
        }
        let items = [withWeather(pressure: 1000, pain: 9), withWeather(pressure: 1002, pain: 8), withWeather(pressure: 1005, pain: 9),
                     withWeather(pressure: 1020, pain: 3), withWeather(pressure: 1018, pain: 2)]
        let insight = try #require(InsightRules.weather(items).first { $0.title.contains("Lower pressure") })
        #expect(insight.priority == .medium)
    }

    @Test func intensityPatternDetectsBuildingPain() throws {
        func building() -> Migraine {
            let migraine = makeMigraine(start: now.addingTimeInterval(-7200), end: now, pain: 8)
            migraine.intensitySamples = [
                IntensitySample(timestamp: now.addingTimeInterval(-7200), painLevel: 3, stressLevel: 3, parentMigraine: migraine),
                IntensitySample(timestamp: now, painLevel: 8, stressLevel: 4, parentMigraine: migraine),
            ]
            return migraine
        }
        let insights = InsightRules.intensityPatterns([building(), building(), building()])
        #expect(insights.contains { $0.title == "Pain tends to build over time" })
    }

    @Test func generateAllDeduplicates() {
        let items = (0..<4).map { i in
            makeMigraine(start: now.addingTimeInterval(Double(-i) * 86_400), triggers: [.stress])
        }
        let all = InsightRules.generateAll(from: items, now: now, calendar: calendar)
        let keys = all.map(\.dedupeKey)
        #expect(Set(keys).count == keys.count)
    }

    @Test func sorterOrdersByPriorityThenCategory() {
        let low = Insight(category: .foods, title: "a", message: "", priority: .low)
        let high = Insight(category: .triggers, title: "b", message: "", priority: .high)
        #expect([low, high].sorted(by: Insight.sorter).first?.priority == .high)
    }
}
