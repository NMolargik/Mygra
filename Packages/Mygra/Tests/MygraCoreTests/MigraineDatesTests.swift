//
//  MigraineDatesTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("MigraineDates")
struct MigraineDatesTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Indiana/Indianapolis")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test("nil date yields zero days")
    func nilDate() {
        #expect(MigraineDates.daysSince(nil, now: date(2026, 6, 10), calendar: calendar) == 0)
    }

    @Test("same day yields zero")
    func sameDay() {
        #expect(MigraineDates.daysSince(date(2026, 6, 10, 1), now: date(2026, 6, 10, 23), calendar: calendar) == 0)
    }

    @Test("late evening to early morning counts one calendar day")
    func calendarDaySemantics() {
        #expect(MigraineDates.daysSince(date(2026, 6, 9, 23), now: date(2026, 6, 10, 1), calendar: calendar) == 1)
    }

    @Test("future dates clamp to zero")
    func futureClamp() {
        #expect(MigraineDates.daysSince(date(2026, 6, 12), now: date(2026, 6, 10), calendar: calendar) == 0)
    }

    @Test(arguments: [
        (0, "0:00"), (59, "0:59"), (60, "1:00"), (3599, "59:59"), (3600, "1:00:00"), (3661, "1:01:01"), (-5, "0:00"),
    ])
    func elapsedString(seconds: Int, expected: String) {
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(MigraineDates.elapsedString(since: start, now: start.addingTimeInterval(TimeInterval(seconds))) == expected)
    }

    @Test(arguments: [
        (0.0, "0m 00s"), (65.0, "1m 05s"), (3600.0, "1h 00m 00s"), (7325.0, "2h 02m 05s"), (-10.0, "0m 00s"),
    ])
    func durationString(seconds: Double, expected: String) {
        #expect(MigraineDates.durationString(seconds) == expected)
    }

    @Test(arguments: [(0.0, "0m"), (1800.0, "30m"), (5400.0, "1h 30m")])
    func compactDuration(seconds: Double, expected: String) {
        #expect(MigraineDates.compactDurationString(seconds) == expected)
    }

    @Test("nextMidnight lands shortly after midnight")
    func nextMidnightTest() {
        let next = MigraineDates.nextMidnight(after: date(2026, 6, 10, 15, 30), calendar: calendar)
        let comps = calendar.dateComponents([.day, .hour, .minute, .second], from: next)
        #expect(comps.day == 11)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 5)
    }

    @Test("health window covers the whole day for past starts and caps at now for today")
    func healthWindow() {
        let now = date(2026, 6, 10, 15)
        let past = MigraineDates.healthWindow(forStart: date(2026, 6, 8, 9), now: now, calendar: calendar)
        #expect(past.start == date(2026, 6, 8, 0))
        #expect(past.end == date(2026, 6, 9, 0))

        let today = MigraineDates.healthWindow(forStart: date(2026, 6, 10, 9), now: now, calendar: calendar)
        #expect(today.start == date(2026, 6, 10, 0))
        #expect(today.end == now)
    }
}
