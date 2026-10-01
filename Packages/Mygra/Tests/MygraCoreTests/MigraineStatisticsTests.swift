//
//  MigraineStatisticsTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("MigraineStatistics")
@MainActor
struct MigraineStatisticsTests {
    @Test func averagesOfEmptyCollectionAreNil() {
        #expect(MigraineStatistics.averageSeverity([]) == nil)
        #expect(MigraineStatistics.averageDurationHours([]) == nil)
        #expect(MigraineStatistics.lastMigraineDate([]) == nil)
    }

    @Test func averageSeverity() {
        let items = [makeMigraine(pain: 2), makeMigraine(pain: 4), makeMigraine(pain: 9)]
        #expect(MigraineStatistics.averageSeverity(items) == 5.0)
    }

    @Test func averageDurationIgnoresOngoing() {
        let now = Date()
        let items = [
            makeMigraine(start: now.addingTimeInterval(-7200), end: now),
            makeMigraine(start: now.addingTimeInterval(-3600), end: nil),
            makeMigraine(start: now.addingTimeInterval(-14400), end: now.addingTimeInterval(-10800)),
        ]
        #expect(MigraineStatistics.averageDurationHours(items) == 1.5)
    }

    @Test func lastMigraineDatePrefersEndDate() {
        let now = Date()
        let older = makeMigraine(start: now.addingTimeInterval(-10 * 86_400), end: now.addingTimeInterval(-9 * 86_400))
        let newerOngoing = makeMigraine(start: now.addingTimeInterval(-3600))
        #expect(MigraineStatistics.lastMigraineDate([older, newerOngoing]) == newerOngoing.startDate)
    }

    @Test func streakDaysCountsFromLastEvent() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Indiana/Indianapolis")!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 9))!
        let end = cal.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 22))!
        let items = [makeMigraine(start: end.addingTimeInterval(-3600), end: end)]
        #expect(MigraineStatistics.streakDays(items, now: now, calendar: cal) == 3)
    }

    @Test func migrainesOnDayMatchesCalendarDay() {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 8))!
        let sameDay = makeMigraine(start: day.addingTimeInterval(3600))
        let otherDay = makeMigraine(start: day.addingTimeInterval(-86_400))
        #expect(MigraineStatistics.migraines([sameDay, otherDay], on: day, calendar: cal).count == 1)
    }
}
