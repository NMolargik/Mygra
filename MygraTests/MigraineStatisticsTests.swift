//
//  MigraineStatisticsTests.swift
//  MygraTests
//

import Foundation
import SwiftData
import Testing
@testable import Mygra

@Suite("MigraineStatistics", .serialized)
@MainActor
struct MigraineStatisticsTests {
    @Test func averagesOfEmptyCollectionAreNil() {
        #expect(MigraineStatistics.averageSeverity([]) == nil)
        #expect(MigraineStatistics.averageDurationHours([]) == nil)
        #expect(MigraineStatistics.lastMigraineDate([]) == nil)
    }

    @Test func averageSeverity() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        let items = [
            makeMigraine(in: ctx, pain: 2),
            makeMigraine(in: ctx, pain: 4),
            makeMigraine(in: ctx, pain: 9),
        ]
        #expect(MigraineStatistics.averageSeverity(items) == 5.0)
    }

    @Test func averageDurationIgnoresOngoing() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        let now = Date()
        let items = [
            makeMigraine(in: ctx, start: now.addingTimeInterval(-7200), end: now), // 2h
            makeMigraine(in: ctx, start: now.addingTimeInterval(-3600), end: nil), // ongoing, ignored
            makeMigraine(in: ctx, start: now.addingTimeInterval(-14400), end: now.addingTimeInterval(-10800)), // 1h
        ]
        #expect(MigraineStatistics.averageDurationHours(items) == 1.5)
    }

    @Test func lastMigraineDatePrefersEndDate() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        let now = Date()
        let older = makeMigraine(in: ctx, start: now.addingTimeInterval(-10 * 24 * 3600), end: now.addingTimeInterval(-9 * 24 * 3600))
        _ = older
        let newerOngoing = makeMigraine(in: ctx, start: now.addingTimeInterval(-3600))
        let items = [older, newerOngoing]
        #expect(MigraineStatistics.lastMigraineDate(items) == newerOngoing.startDate)
    }

    @Test func streakDaysCountsFromLastEvent() throws {
        let container = try makeTestContainer()
        let ctx = container.mainContext
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Indiana/Indianapolis")!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 9))!
        let end = cal.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 22))!
        let items = [makeMigraine(in: ctx, start: end.addingTimeInterval(-3600), end: end)]
        #expect(MigraineStatistics.streakDays(items, now: now, calendar: cal) == 3)
    }
}
