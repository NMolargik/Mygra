//
//  MenstrualCycle.swift
//  MygraCore
//
//  Pure statistics for the menstrual-cycle correlation: period starts from daily flow
//  records, and the share of attacks that began in the perimenstrual window (2 days
//  before to 3 days after the first day of flow) compared with the share expected by
//  chance given each cycle's length. Nothing here touches HealthKit; the Services layer
//  hands in the flow days. The output is descriptive and never a diagnosis.
//
//  Method (documented because the report prints it):
//  - A "period start" is a flow day with no flow in the previous `periodGapDays` days.
//  - A completed cycle runs from one period start up to (not including) the next. Cycles
//    shorter than 15 or longer than 60 days are skipped as probably incomplete records.
//  - The window is 6 calendar days: start-2 ... start+3. Within a cycle of length L it
//    covers the first 4 days and the last 2, so chance alone puts 6/L of a cycle's days
//    in the window.
//  - Expected attacks in the window = sum over attacks of 6/L for the attack's cycle;
//    ratio = observed / expected. Only attacks inside completed cycles are counted.
//  - Nothing is claimed with fewer than 3 completed cycles or 5 attacks inside them.
//

import Foundation

nonisolated public struct PerimenstrualAnalysis: Equatable, Sendable {
    /// Completed cycles that were usable.
    public let cycleCount: Int
    /// Attacks that started inside those cycles.
    public let totalAttacks: Int
    /// Of those, attacks that started in the 2-days-before to 3-days-after window.
    public let attacksInWindow: Int
    /// Attacks expected in the window if attacks ignored the cycle.
    public let expectedAttacksInWindow: Double

    public init(cycleCount: Int, totalAttacks: Int, attacksInWindow: Int, expectedAttacksInWindow: Double) {
        self.cycleCount = cycleCount
        self.totalAttacks = totalAttacks
        self.attacksInWindow = attacksInWindow
        self.expectedAttacksInWindow = expectedAttacksInWindow
    }

    public var observedShare: Double { totalAttacks == 0 ? 0 : Double(attacksInWindow) / Double(totalAttacks) }
    public var expectedShare: Double { totalAttacks == 0 ? 0 : expectedAttacksInWindow / Double(totalAttacks) }
    /// Observed over expected; nil when nothing was expected.
    public var ratio: Double? { expectedAttacksInWindow > 0 ? Double(attacksInWindow) / expectedAttacksInWindow : nil }
}

nonisolated public enum PerimenstrualResult: Equatable, Sendable {
    case insufficient(cycles: Int, attacks: Int)
    case result(PerimenstrualAnalysis)
}

nonisolated public enum MenstrualCycles {
    public static let daysBefore = 2
    public static let daysAfter = 3
    /// Days in the window: 2 before, the start day, and 3 after.
    public static let windowLength = daysBefore + 1 + daysAfter
    public static let minimumCycles = 3
    public static let minimumAttacks = 5
    public static let plausibleCycleLengths = 15...60
    /// A flow day this many days after the previous one begins a new period.
    public static let periodGapDays = 10
    /// A ratio at or above this is described as "about N times" chance.
    public static let elevatedRatio = 1.5
    /// A ratio at or below this is described as less than chance.
    public static let reducedRatio = 0.67

    // MARK: - Period starts

    /// First day of each period, from the days on which any flow was recorded.
    public static func periodStarts<S: Sequence<Date>>(fromFlowDays flowDays: S, calendar: Calendar = .current) -> [Date] {
        let days = Set(flowDays.map { calendar.startOfDay(for: $0) }).sorted()
        var starts: [Date] = []
        var previous: Date?
        for day in days {
            if let previous, dayCount(from: previous, to: day, calendar: calendar) < periodGapDays {
                // Same period.
            } else {
                starts.append(day)
            }
            previous = day
        }
        return starts
    }

    static func dayCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    // MARK: - Analysis

    public static func analyze(attackStarts: [Date], periodStarts: [Date], calendar: Calendar = .current) -> PerimenstrualResult {
        let starts = Array(Set(periodStarts.map { calendar.startOfDay(for: $0) })).sorted()
        var cycles = 0
        var total = 0
        var inWindow = 0
        var expected = 0.0
        let attackDays = attackStarts.map { calendar.startOfDay(for: $0) }

        for index in 0..<max(0, starts.count - 1) {
            let first = starts[index]
            let next = starts[index + 1]
            let length = dayCount(from: first, to: next, calendar: calendar)
            guard plausibleCycleLengths.contains(length) else { continue }
            cycles += 1
            for day in attackDays where day >= first && day < next {
                let offset = dayCount(from: first, to: day, calendar: calendar)
                total += 1
                expected += Double(windowLength) / Double(length)
                if offset <= daysAfter || offset >= length - daysBefore { inWindow += 1 }
            }
        }

        guard cycles >= minimumCycles, total >= minimumAttacks else {
            return .insufficient(cycles: cycles, attacks: total)
        }
        return .result(PerimenstrualAnalysis(cycleCount: cycles, totalAttacks: total, attacksInWindow: inWindow, expectedAttacksInWindow: expected))
    }

    // MARK: - Wording (descriptive, never diagnostic)

    public static func summary(_ analysis: PerimenstrualAnalysis) -> String {
        let percent = Int((analysis.observedShare * 100).rounded())
        let expectedPercent = Int((analysis.expectedShare * 100).rounded())
        guard let ratio = analysis.ratio else {
            return String(localized: "\(percent)% of your attacks started within 2 days before to 3 days after your period starts.")
        }
        if ratio >= elevatedRatio {
            return String(localized: "\(percent)% of your attacks started within 2 days before to 3 days after your period starts, about \(timesText(ratio)) times what chance would predict.")
        }
        if ratio <= reducedRatio {
            return String(localized: "\(percent)% of your attacks started within 2 days before to 3 days after your period starts, less than the \(expectedPercent)% chance would predict.")
        }
        return String(localized: "\(percent)% of your attacks started within 2 days before to 3 days after your period starts, close to the \(expectedPercent)% chance would predict.")
    }

    public static func basis(_ analysis: PerimenstrualAnalysis) -> String {
        String(localized: "Based on \(analysis.totalAttacks) attacks across \(analysis.cycleCount) cycles. This describes your logged data and does not show a cause.")
    }

    public static func insufficientMessage(cycles: Int, attacks: Int) -> String {
        String(localized: "Not enough data yet. This needs at least \(minimumCycles) completed cycles and \(minimumAttacks) attacks inside them. Right now there are \(cycles) cycles and \(attacks) attacks.")
    }

    /// "3", "2.5", or "10 or more": whole numbers lose the decimal.
    static func timesText(_ ratio: Double) -> String {
        if ratio >= 10 { return String(localized: "10 or more") }
        let rounded = (ratio * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    // MARK: - Report

    /// The clinical-report section. `nil` result (feature off) adds nothing.
    public static func reportBlocks(_ result: PerimenstrualResult?) -> [ReportBlock] {
        guard let result else { return [] }
        var blocks: [ReportBlock] = [.sectionHeader(String(localized: "Menstrual Cycle Pattern")), .spacer(6)]
        switch result {
        case .insufficient(let cycles, let attacks):
            blocks.append(.body(insufficientMessage(cycles: cycles, attacks: attacks)))
        case .result(let analysis):
            blocks.append(.body(summary(analysis)))
            blocks.append(.body(String(localized: "Attacks in the window: \(analysis.attacksInWindow) of \(analysis.totalAttacks). Expected by chance: \(String(format: "%.1f", analysis.expectedAttacksInWindow))")))
            blocks.append(.body(basis(analysis)))
        }
        blocks.append(.body(String(localized: "Cycle days come from Apple Health. The window is the 2 days before to 3 days after the first day of flow. Chance is estimated from each cycle's length.")))
        blocks.append(.spacer(12))
        return blocks
    }
}
