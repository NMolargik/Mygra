//
//  Array-.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import Foundation

public extension Array where Element == MigraineTrigger {
    /// Default grouping order for a grid UI.
    static var defaultGridOrder: [MigraineTrigger] {
        return [
            // Lifestyle
            .stress, .lackOfSleep, .oversleeping, .skippedMeals, .dehydration,
            .jetLag, .shiftWork, .screenTimeFlicker, .postureNeckTension, .bruxismTeethGrinding,
            // Hormonal
            .hormonalFluctuation,
            // Dietary
            .alcoholRedWine, .caffeineExcess, .caffeineWithdrawal, .chocolate, .agedCheese, .processedMeatsNitrates, .msg, .aspartame,
            // Sensory
            .brightLightGlare, .loudNoise, .strongOdors,
            // Weather
            .barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind,
            // Physical & Meds
            .intenseExercise, .certainMedications, .medicationOveruse,
            // Other
            .other
        ]
    }
}
