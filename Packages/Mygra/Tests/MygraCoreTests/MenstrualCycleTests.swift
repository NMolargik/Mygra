//
//  MenstrualCycleTests.swift
//  MygraCoreTests
//
//  Period-start detection and the perimenstrual-window statistic.
//

import Foundation
import Testing
import MygraCore

@Suite("MenstrualCycles")
struct MenstrualCycleTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Day `n` after 2026-01-01 UTC.
    private func day(_ n: Int) -> Date {
        utc.date(byAdding: .day, value: n, to: utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!)!
    }

    /// Period starts every `length` days from day 0: `count` starts.
    private func starts(length: Int = 28, count: Int) -> [Date] {
        (0..<count).map { day($0 * length) }
    }

    // MARK: Period starts

    @Test("consecutive flow days collapse to one period start")
    func periodStartsCollapse() {
        let flow = [0, 1, 2, 3, 4, 28, 29, 30, 31].map(day)
        let result = MenstrualCycles.periodStarts(fromFlowDays: flow, calendar: utc)
        #expect(result == [day(0), day(28)])
    }

    @Test("a short gap inside a period does not start a new one")
    func gapInsidePeriod() {
        let flow = [0, 1, 5, 6].map(day)
        #expect(MenstrualCycles.periodStarts(fromFlowDays: flow, calendar: utc) == [day(0)])
    }

    @Test("duplicates and time of day are normalized")
    func normalization() {
        let flow = [day(0).addingTimeInterval(3600), day(0).addingTimeInterval(7200), day(30)]
        #expect(MenstrualCycles.periodStarts(fromFlowDays: flow, calendar: utc) == [day(0), day(30)])
    }

    // MARK: Window math

    @Test("the window is 2 days before through 3 days after the first flow day")
    func windowEdges() {
        // 4 starts => 3 cycles of 28 days. Attack days relative to the cycle starts.
        let periods = starts(count: 4)
        // In window: start (0), +3, and the two days before the next start (26, 27).
        // Out of window: +4 and 25.
        let inside = [day(28 + 0), day(28 + 3), day(28 + 26), day(28 + 27)]
        let outside = [day(28 + 4), day(28 + 25)]
        guard case .result(let analysis) = MenstrualCycles.analyze(attackStarts: inside + outside, periodStarts: periods, calendar: utc) else {
            Issue.record("expected a result"); return
        }
        #expect(analysis.totalAttacks == 6)
        #expect(analysis.attacksInWindow == 4)
    }

    @Test("an attack two days before a period belongs to the earlier cycle's window")
    func acrossCycleBoundary() {
        let periods = starts(count: 4)
        // Day 26 and 27 of cycle 1 are days -2 and -1 of cycle 2's period start.
        let attacks = [day(26), day(27), day(54), day(55), day(80)]
        guard case .result(let analysis) = MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) else {
            Issue.record("expected a result"); return
        }
        #expect(analysis.attacksInWindow == 4)
        #expect(analysis.totalAttacks == 5)
    }

    @Test("expected share is window length over cycle length")
    func expectedShare() {
        let periods = starts(length: 30, count: 4)
        let attacks = [day(10), day(11), day(12), day(40), day(41), day(70)]
        guard case .result(let analysis) = MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) else {
            Issue.record("expected a result"); return
        }
        #expect(abs(analysis.expectedShare - 6.0 / 30.0) < 1e-9)
        #expect(analysis.attacksInWindow == 0)
        #expect(analysis.ratio == 0)
    }

    @Test("chance is weighted by each cycle's own length")
    func variableCycleLengths() {
        // Cycles of 24, 30, 36 days.
        let periods = [day(0), day(24), day(54), day(90)]
        let attacks = [day(5), day(30), day(60), day(70), day(80)]
        guard case .result(let analysis) = MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) else {
            Issue.record("expected a result"); return
        }
        let expected = 6.0 / 24 + 2 * (6.0 / 30) + 2 * (6.0 / 36)
        // day(5) is cycle 1 (24 days); day(30) is +6 of cycle 2; 60, 70, 80 are in cycle 3.
        let manual = 6.0 / 24 + 6.0 / 30 + 3 * (6.0 / 36)
        #expect(abs(analysis.expectedAttacksInWindow - manual) < 1e-9)
        #expect(expected != manual)
    }

    @Test("attacks outside the completed cycles are ignored")
    func outsideCycles() {
        let periods = starts(count: 4) // cycles cover day 0 ..< day 84
        let attacks = [day(-5), day(100), day(10), day(11), day(12), day(40), day(41)]
        guard case .result(let analysis) = MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) else {
            Issue.record("expected a result"); return
        }
        #expect(analysis.totalAttacks == 5)
    }

    @Test("implausible cycle lengths are skipped")
    func implausibleCycles() {
        // 90-day gap then three normal cycles.
        let periods = [day(0), day(90), day(118), day(146), day(174)]
        let attacks = [day(10), day(95), day(120), day(150), day(160), day(100)]
        guard case .result(let analysis) = MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) else {
            Issue.record("expected a result"); return
        }
        #expect(analysis.cycleCount == 3)
        #expect(analysis.totalAttacks == 5) // day(10) sits in the skipped 90-day cycle
    }

    // MARK: Minimums

    @Test("fewer than three completed cycles claims nothing")
    func tooFewCycles() {
        let periods = starts(count: 3) // 2 cycles
        let attacks = (0..<10).map { day($0 * 5) }
        #expect(MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) == .insufficient(cycles: 2, attacks: 10))
    }

    @Test("fewer than five attacks claims nothing")
    func tooFewAttacks() {
        let periods = starts(count: 5)
        let attacks = [day(1), day(2), day(40), day(70)]
        #expect(MenstrualCycles.analyze(attackStarts: attacks, periodStarts: periods, calendar: utc) == .insufficient(cycles: 4, attacks: 4))
    }

    @Test("no cycle data at all is insufficient")
    func noData() {
        #expect(MenstrualCycles.analyze(attackStarts: [day(1)], periodStarts: [], calendar: utc) == .insufficient(cycles: 0, attacks: 0))
    }

    // MARK: Wording

    @Test("an elevated ratio reads as a multiple of chance")
    func elevatedSentence() {
        let analysis = PerimenstrualAnalysis(cycleCount: 6, totalAttacks: 13, attacksInWindow: 8, expectedAttacksInWindow: 2.7)
        let text = MenstrualCycles.summary(analysis)
        #expect(text.contains("62%"))
        #expect(text.contains("about 3 times what chance would predict"))
        #expect(!text.contains("—"))
    }

    @Test("a near-chance ratio says so and a low one says less")
    func otherSentences() {
        let near = PerimenstrualAnalysis(cycleCount: 4, totalAttacks: 10, attacksInWindow: 2, expectedAttacksInWindow: 2)
        #expect(MenstrualCycles.summary(near).contains("close to"))
        let low = PerimenstrualAnalysis(cycleCount: 4, totalAttacks: 10, attacksInWindow: 0, expectedAttacksInWindow: 2)
        #expect(MenstrualCycles.summary(low).contains("less than"))
    }

    @Test("report blocks are empty when the feature is off")
    func reportBlocks() {
        #expect(MenstrualCycles.reportBlocks(nil).isEmpty)
        let blocks = MenstrualCycles.reportBlocks(.insufficient(cycles: 1, attacks: 2))
        #expect(blocks.contains(.sectionHeader("Menstrual Cycle Pattern")))
    }

    @Test("the clinical report includes the section when a result is supplied")
    func clinicalReportSection() {
        let analysis = PerimenstrualAnalysis(cycleCount: 6, totalAttacks: 13, attacksInWindow: 8, expectedAttacksInWindow: 2.7)
        let blocks = ClinicalReport.blocks(user: nil, migraines: [], useMetricUnits: true, useDMY: false, perimenstrual: .result(analysis), now: day(100), calendar: utc)
        #expect(blocks.contains(.sectionHeader("Menstrual Cycle Pattern")))
        let without = ClinicalReport.blocks(user: nil, migraines: [], useMetricUnits: true, useDMY: false, now: day(100), calendar: utc)
        #expect(!without.contains(.sectionHeader("Menstrual Cycle Pattern")))
    }
}
