//
//  MigraineDatesTests.swift
//  MygraTests
//

import Foundation
import Testing
@testable import Mygra

@Suite("MigraineDates")
struct MigraineDatesTests {
    /// Fixed reference: 2026-06-10 15:30 local.
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
        // 11 PM yesterday → 1 AM today is one calendar day even though only
        // two hours elapsed.
        let lateYesterday = date(2026, 6, 9, 23)
        let earlyToday = date(2026, 6, 10, 1)
        #expect(MigraineDates.daysSince(lateYesterday, now: earlyToday, calendar: calendar) == 1)
    }

    @Test("future dates clamp to zero")
    func futureClamp() {
        #expect(MigraineDates.daysSince(date(2026, 6, 12), now: date(2026, 6, 10), calendar: calendar) == 0)
    }

    @Test(arguments: [
        (0, "0:00"),
        (59, "0:59"),
        (60, "1:00"),
        (3599, "59:59"),
        (3600, "1:00:00"),
        (3661, "1:01:01"),
        (-5, "0:00"),
    ])
    func elapsedString(seconds: Int, expected: String) {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now = start.addingTimeInterval(TimeInterval(seconds))
        #expect(MigraineDates.elapsedString(since: start, now: now) == expected)
    }

    @Test("nextMidnight lands shortly after midnight")
    func nextMidnightTest() {
        let from = date(2026, 6, 10, 15, 30)
        let next = MigraineDates.nextMidnight(after: from, calendar: calendar)
        let comps = calendar.dateComponents([.day, .hour, .minute, .second], from: next)
        #expect(comps.day == 11)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 5)
    }
}
