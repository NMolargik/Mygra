//
//  InsightRulesTests.swift
//  MygraTests
//

import Foundation
import SwiftData
import Testing
@testable import Mygra

@Suite("InsightRules", .serialized)
@MainActor
struct InsightRulesTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000) // fixed reference
    private let calendar = Calendar(identifier: .gregorian)

    @Test func emptyInputYieldsNoInsights() {
        #expect(InsightRules.generateAll(from: [], now: now, calendar: calendar).isEmpty)
    }

    @Test func risingFrequencyIsHighPriority() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        // 3 in the last 14 days, 1 in the prior 14 days.
        var items: [Migraine] = []
        for daysAgo in [2, 5, 9] {
            items.append(makeMigraine(in: ctx, start: now.addingTimeInterval(Double(-daysAgo) * 86_400)))
        }
        items.append(makeMigraine(in: ctx, start: now.addingTimeInterval(-20 * 86_400)))

        let trends = InsightRules.trends(items, now: now, calendar: calendar)
        let frequency = try #require(trends.first { $0.category == .trendFrequency })
        #expect(frequency.priority == .high)
        #expect(frequency.title.contains("increased"))
    }

    @Test func commonTriggerSurfacesWithPercentage() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        let items = (0..<4).map { i in
            makeMigraine(
                in: ctx,
                start: now.addingTimeInterval(Double(-i) * 86_400),
                triggers: i < 3 ? [.stress] : []
            )
        }

        let insights = InsightRules.triggers(items)
        let stress = try #require(insights.first { $0.title.contains("Stress") || $0.message.contains("75%") })
        #expect(stress.priority == .high) // 75% ≥ 40%
    }

    @Test func customTriggersAreGroupedCaseInsensitively() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        let items = [
            makeMigraine(in: ctx, start: now, customTriggers: ["red wine"]),
            makeMigraine(in: ctx, start: now, customTriggers: ["Red Wine"]),
        ]
        let insights = InsightRules.triggers(items)
        // Both spellings should be capitalized into one bucket appearing in 100% of migraines.
        let wine = try #require(insights.first { $0.title.contains("Red Wine") })
        #expect(wine.message.contains("100%"))
    }

    @Test func sleepRuleNeedsFiveSamplesAndOnePointGap() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext

        func attach(_ sleep: Double, pain: Int) -> Migraine {
            let m = makeMigraine(in: ctx, start: now, pain: pain)
            let health = HealthData(sleepHours: sleep)
            ctx.insert(health)
            m.health = health
            return m
        }

        // 3 short-sleep high-pain, 2 long-sleep low-pain
        var items = [
            attach(5, pain: 8), attach(6, pain: 9), attach(5.5, pain: 8),
            attach(8, pain: 3), attach(9, pain: 2),
        ]
        let insights = InsightRules.sleep(items)
        #expect(insights.count == 1)
        #expect(insights.first?.category == .sleepAssociation)

        // With only 4 samples, nothing fires.
        items.removeLast()
        let m = items.removeLast()
        m.health = nil
        items.append(m)
        #expect(InsightRules.sleep(items).isEmpty)
    }

    @Test func generateAllDeduplicates() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        let items = (0..<4).map { i in
            makeMigraine(
                in: ctx,
                start: now.addingTimeInterval(Double(-i) * 86_400),
                triggers: [.stress]
            )
        }
        let all = InsightRules.generateAll(from: items, now: now, calendar: calendar)
        let keys = all.map(\.dedupeKey)
        #expect(Set(keys).count == keys.count)
    }
}
