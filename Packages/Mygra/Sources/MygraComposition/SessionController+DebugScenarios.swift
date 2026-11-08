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
#endif
