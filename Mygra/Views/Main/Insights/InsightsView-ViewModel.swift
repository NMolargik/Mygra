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
        var addWater: Double = 0        // liters
        var addCaffeine: Double = 0     // mg
        var addFood: Double = 0     // kcal
        var addSleepHours: Double = 0   // hours
        var isSavingIntake: Bool = false
        var intakeError: String?

        var isQuickAddExpanded: Bool = false
        var isShowingMigraineAssistant: Bool = false
        
        var allIntakeAddsAreZero: Bool {
            addWater == 0 && addCaffeine == 0 && addFood == 0 && addSleepHours == 0
        }
        
        func resetIntakeInputs() {
            addWater = 0
            addCaffeine = 0
            addFood = 0
            addSleepHours = 0
            intakeError = nil
        }
    }
}
