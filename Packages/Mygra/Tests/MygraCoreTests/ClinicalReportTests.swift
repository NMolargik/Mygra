//
//  ClinicalReportTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
@testable import MygraCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
private let now = Date(timeIntervalSince1970: 1_794_052_800) // 2026-11-07 12:00 UTC

@MainActor
private func attack(daysAgo: Double, hours: Double = 2, pain: Int = 6, triggers: [MigraineTrigger] = []) -> Migraine {
    let start = now.addingTimeInterval(-daysAgo * 86_400)
    return Migraine(startDate: start, endDate: start.addingTimeInterval(hours * 3600), painLevel: pain, stressLevel: 3, triggers: triggers)
}

@Suite("ClinicalReport")
@MainActor
struct ClinicalReportTests {

    private func tables(_ blocks: [ReportBlock]) -> [ReportTable] {
        blocks.compactMap { if case .table(let t) = $0 { t } else { nil } }
    }

    @Test func headacheDaysCountDistinctDaysIncludingOvernightAttacks() {
        let window = ClinicalReport.window(months: 1, now: now, calendar: utc)
        let two = attack(daysAgo: 3, hours: 1)
        let sameDay = attack(daysAgo: 3, hours: 1)
        let overnight = attack(daysAgo: 5.2, hours: 20) // spans two calendar days
        let days = ClinicalReport.headacheDays([two, sameDay, overnight], in: window, now: now, calendar: utc)
        #expect(days.count == 3)
    }

    @Test func migraineDayNeedsPainFourOrFourHours() {
        let mild = attack(daysAgo: 2, hours: 1, pain: 2)
        let painful = attack(daysAgo: 4, hours: 1, pain: 5)
        let long = attack(daysAgo: 6, hours: 5, pain: 2)
        let window = ClinicalReport.window(months: 1, now: now, calendar: utc)
        #expect(ClinicalReport.headacheDays([mild, painful, long], in: window, now: now, calendar: utc).count == 3)
        #expect(ClinicalReport.migraineDays([mild, painful, long], in: window, now: now, calendar: utc).count == 2)
    }

    @Test func windowOptionsAreOneThreeSix() {
        #expect(ClinicalReportOptions(months: 2).months == 3)
        for months in ClinicalReportOptions.allowedMonths {
            #expect(ClinicalReportOptions(months: months).months == months)
        }
    }

    @Test func attacksOutsideTheWindowAreExcluded() {
        let recent = attack(daysAgo: 10)
        let old = attack(daysAgo: 100)
        let blocks = ClinicalReport.blocks(user: nil, migraines: [recent, old], options: .init(months: 1), useMetricUnits: true, useDMY: false, now: now, calendar: utc)
        #expect(blocks.contains(.sectionHeader("Attack Detail (1)")))
        let months = tables(blocks).first
        let total = months?.rows.first { $0.first == "Total" }
        #expect(total?[1] == "1")
    }

    @Test func medicationTableMarksClassesOverThreshold() {
        let migraine = attack(daysAgo: 1)
        migraine.medications = (0..<10).map { offset in
            MedicationDose(name: "Sumatriptan", medicationClass: .triptan, takenAt: now.addingTimeInterval(-Double(offset) * 86_400), migraine: migraine)
        } + (0..<3).map { offset in
            MedicationDose(name: "Ibuprofen", medicationClass: .simpleAnalgesic, takenAt: now.addingTimeInterval(-Double(offset) * 86_400), migraine: migraine)
        }
        let blocks = ClinicalReport.blocks(user: nil, migraines: [migraine], options: .init(months: 1), useMetricUnits: true, useDMY: false, now: now, calendar: utc)
        let table = try! #require(tables(blocks).first { $0.columns.first == "Class" })
        let triptan = try! #require(table.rows.first { $0[0].hasPrefix("Triptan") })
        #expect(triptan[0].contains("⚠"))
        #expect(triptan.last == "10+ days")
        let simple = try! #require(table.rows.first { $0[0].hasPrefix("Simple") })
        #expect(!simple[0].contains("⚠"))
        #expect(simple.last == "15+ days")
        #expect(table.highlightedRows.count == 1)
    }

    @Test func emptyMedicationSaysSo() {
        let blocks = ClinicalReport.blocks(user: nil, migraines: [attack(daysAgo: 1)], options: .init(months: 1), useMetricUnits: true, useDMY: false, now: now, calendar: utc)
        #expect(blocks.contains(.body("No acute medication recorded in this period.")))
    }

    @Test func questionnairesPrintScoreAndBand() {
        let assessment = ClinicalAssessment(midasAnswers: [5, 5, 5, 0, 0], hit6Answers: Array(repeating: .always, count: 6))
        let blocks = ClinicalReport.assessmentBlocks(assessment, useDMY: false)
        let text = blocks.compactMap { if case .body(let t) = $0 { t } else { nil } }
        #expect(text.contains { $0.contains("MIDAS: 15") && $0.contains("Grade III") })
        #expect(text.contains { $0.contains("HIT-6: 78") && $0.contains("Severe impact") })

        let none = ClinicalReport.assessmentBlocks(ClinicalAssessment(), useDMY: false)
        #expect(none.contains(.body("MIDAS: not completed")))
        #expect(none.contains(.body("HIT-6: not completed")))
    }

    @Test func triggerFrequencyTableCountsAttacksAndPercent() {
        let a = attack(daysAgo: 1, triggers: [.stress, .lackOfSleep])
        let b = attack(daysAgo: 2, triggers: [.stress])
        let blocks = ClinicalReport.frequencyBlocks(migraines: [a, b])
        let table = try! #require(tables(blocks).first)
        let stress = try! #require(table.rows.first { $0[0] == MigraineTrigger.stress.displayName })
        #expect(stress[1] == "2")
        #expect(stress[2] == "100%")
    }

    @Test func oneCurvePerAttackWithSampleTimeline() {
        let a = attack(daysAgo: 1, hours: 3)
        a.intensitySamples = [
            IntensitySample(timestamp: a.startDate, painLevel: 4, parentMigraine: a),
            IntensitySample(timestamp: a.startDate.addingTimeInterval(1800), painLevel: 8, parentMigraine: a),
        ]
        let b = attack(daysAgo: 2) // no samples: falls back to headline level
        let curves = ClinicalReport.curveBlocks(migraines: [a, b], now: now, useDMY: false)
            .compactMap { if case .curve(let c) = $0 { c } else { nil } }
        #expect(curves.count == 2)
        let withSamples = try! #require(curves.first { $0.points.count == 2 })
        #expect(withSamples.points.map(\.minutes) == [0, 30])
        #expect(withSamples.points.map(\.pain) == [4, 8])
        #expect(curves.contains { $0.points.count == 1 && $0.points[0].pain == 6 })
    }

    @Test func patientFieldsAreOptIn() {
        let user = User(name: "Pat Example")
        let hidden = ClinicalReport.blocks(user: user, migraines: [], options: .init(months: 1, includeName: false, includeBirthday: false, includeHealthProfile: false), useMetricUnits: true, useDMY: false, now: now, calendar: utc)
        #expect(!hidden.contains(.sectionHeader("Patient")))
        #expect(!hidden.contains { if case .body(let t) = $0 { t.contains("Pat Example") } else { false } })

        let named = ClinicalReport.blocks(user: user, migraines: [], options: .init(months: 1, includeName: true, includeBirthday: false, includeHealthProfile: false), useMetricUnits: true, useDMY: false, now: now, calendar: utc)
        #expect(named.contains(.body("Name: Pat Example")))
        #expect(!named.contains { if case .body(let t) = $0 { t.hasPrefix("Birthday") } else { false } })
    }

    @Test func attackDetailListsMedications() {
        let m = attack(daysAgo: 1)
        m.medications = [MedicationDose(name: "Sumatriptan", medicationClass: .triptan, dose: "50 mg", takenAt: m.startDate, migraine: m)]
        let lines = MigraineReport.detailLines(for: m, useMetricUnits: true, useDMY: false)
        #expect(lines.contains { $0.hasPrefix("Medications: Sumatriptan · 50 mg (Triptan") })
    }
}
