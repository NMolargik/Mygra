//
//  SessionController+DebugScenarios.swift
//  MygraComposition
//
//  DEBUG-only: drives Attack Mode through its real model and use-cases from a launch
//  argument (`-MygraDebugScenario attackActive|attackEnded`), so the screens can be
//  captured on a simulator without tapping. Not compiled into release builds.
//

#if DEBUG
import Foundation
import MygraCore
import MygraServices

extension SessionController {
    /// Seeds a little medication history, then replays an attack the way a user would:
    /// start, pick an intensity step, take a usual medication, and (for `attackEnded`) end it.
    public func runDebugAttackScenario(_ scenario: String) {
        guard scenario == "attackActive" || scenario == "attackEnded" else { return }

        migraineData.deleteAll()
        let now = Date()
        for (daysAgo, doses) in [(20.0, [("Sumatriptan", MedicationClass.triptan, "50 mg")]),
                                 (9.0, [("Sumatriptan", .triptan, "50 mg"), ("Ibuprofen", .simpleAnalgesic, "400 mg")]),
                                 (3.0, [("Ibuprofen", .simpleAnalgesic, "400 mg")])] {
            let start = now.addingTimeInterval(-daysAgo * 86_400)
            let past = Migraine(startDate: start, endDate: start.addingTimeInterval(4 * 3600), painLevel: 6, stressLevel: 4)
            migraineData.log(past)
            for (name, cls, dose) in doses {
                migraineData.logMedication(for: past, name: name, medicationClass: cls, dose: dose, takenAt: start.addingTimeInterval(600))
            }
        }

        attackMode.startAttack()
        attackMode.setIntensity(8)
        if let medication = attackMode.quickMedications.first {
            attackMode.logMedication(medication)
        }
        if scenario == "attackEnded" {
            attackMode.endAttack()
        }
    }
}

// MARK: - Cycle and pressure

extension SessionController {
    /// Seeds a month-by-month history that clusters around period starts, canned period
    /// days from "Health", and a pressure series with three drops (one forecast), so the
    /// cycle and pressure screens can be captured on a simulator without Health or
    /// WeatherKit (`-MygraDebugScenario cyclePressure`). Pair with `-Plus.grandfathered YES`.
    public func runDebugCyclePressureScenario() {
        migraineData.deleteAll()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, hour: Int = 9) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(byAdding: .hour, value: hour, to: base) ?? base
        }

        // Periods start every 28 days; the latest began 5 days ago. Flow lasts 5 days.
        let periodStartOffsets = [-145, -117, -89, -61, -33, -5]
        var flowDays: [Date] = []
        for offset in periodStartOffsets {
            for extra in 0..<5 { flowDays.append(day(offset + extra, hour: 0)) }
        }
        cycleData.installDebugFlowDays(flowDays)

        // Attacks: most start in the window around a period start, a few elsewhere.
        let attackOffsets = [-144, -118, -90, -88, -62, -60, -34, -32, -130, -75, -45, -20]
        for offset in attackOffsets {
            let start = day(offset)
            migraineData.log(Migraine(startDate: start, endDate: start.addingTimeInterval(5 * 3600), painLevel: 6, stressLevel: 4))
        }
        // Recent attacks for the pressure graph.
        for hoursAgo in [20.0, 70.0, 108.0] {
            let start = now.addingTimeInterval(-hoursAgo * 3600)
            migraineData.log(Migraine(startDate: start, endDate: start.addingTimeInterval(4 * 3600), painLevel: 7, stressLevel: 5))
        }

        // Hourly pressure: a gentle swell with falls at -118 h, -30 h, and +4 h (forecast).
        func smooth(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
        func hpa(_ hour: Double) -> Double {
            var p = 1016 + 1.5 * sin(hour / 22)
            p -= 7 * smooth((hour + 126) / 9) - 7 * smooth((hour + 100) / 14)
            p -= 7.5 * smooth((hour + 34) / 9) - 7.5 * smooth((hour + 12) / 16)
            p -= 6.5 * smooth((hour - 2) / 10)
            return p
        }
        let series = (-168...48).map { PressureSample(date: now.addingTimeInterval(Double($0) * 3600), hpa: hpa(Double($0))) }
        weatherManager.installDebugWeather(
            reading: WeatherReading(
                temperature: Measurement(value: 64, unit: .fahrenheit),
                pressure: Measurement(value: hpa(0), unit: .hectopascals),
                humidity: 0.58,
                condition: .cloudy,
                fetchedAt: now
            ),
            pressureSeries: series
        )
    }

    /// Writes the clinical report (with the cycle section) to Documents/debug-report.pdf.
    public func writeDebugClinicalReport() {
        let blocks = ClinicalReport.blocks(
            user: userData.currentUser,
            migraines: migraineData.migraines,
            options: ClinicalReportOptions(months: 6),
            useMetricUnits: false,
            useDMY: false,
            perimenstrual: cycleData.result(for: migraineData.migraines)
        )
        let data = PDFReportRenderer.render(blocks)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: documents.appendingPathComponent("debug-report.pdf"))
        }
    }
}
#endif
