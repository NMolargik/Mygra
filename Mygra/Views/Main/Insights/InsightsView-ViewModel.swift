//
//  InsightsView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation

extension InsightsView {
    @Observable
    class ViewModel {
        // Intake editor state
        var addWater: Double = 0        // liters
        var addCaffeine: Double = 0     // mg
        var addCalories: Double = 0     // kcal
        var addSleepHours: Double = 0   // hours
        var isSavingIntake: Bool = false
        var intakeError: String?

        // UI state
        var isQuickLogExpanded: Bool = false
        var isShowingMigraineAssistant: Bool = false
        
        
        func resetIntakeInputs() {
            addWater = 0
            addCaffeine = 0
            addCalories = 0
            addSleepHours = 0
            intakeError = nil
        }

        var allIntakeAddsAreZero: Bool {
            addWater == 0 && addCaffeine == 0 && addCalories == 0 && addSleepHours == 0
        }
    }
}
