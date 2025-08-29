//
//  MigraineTrigger.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation

/// Common migraine triggers captured as a selectable grid in the UI.
/// This list focuses on broadly reported triggers across reputable sources
/// (American Migraine Foundation, Mayo Clinic, Cleveland Clinic, NHS, etc.).
/// Cases are purposefully granular enough for useful analytics without
/// becoming unmanageably specific.
public enum MigraineTrigger: String, Codable, CaseIterable, Hashable {
    // MARK: - Lifestyle / Routine
    case stress
    case lackOfSleep
    case oversleeping
    case skippedMeals
    case dehydration
    case jetLag
    case shiftWork
    case screenTimeFlicker
    case postureNeckTension
    case bruxismTeethGrinding

    // MARK: - Hormonal
    case hormonalFluctuation    // e.g., menstrual-related changes

    // MARK: - Dietary
    case alcoholRedWine
    case caffeineExcess
    case caffeineWithdrawal
    case chocolate
    case agedCheese
    case processedMeatsNitrates
    case msg
    case aspartame

    // MARK: - Sensory / Environmental (non-weather)
    case brightLightGlare
    case loudNoise
    case strongOdors

    // MARK: - Weather / Atmosphere
    case barometricPressureChange
    case highHumidity
    case heatExtreme
    case coldExtreme
    case stormsWind

    // MARK: - Physical exertion & meds
    case intenseExercise
    case certainMedications
    case medicationOveruse

    // MARK: - Catch-all
    case other
}

// MARK: - Category-specific accessors (for grid building)

public extension MigraineTrigger {
    /// All triggers grouped by the high-level category.
    /// Use this when building sectioned grids.
    static var grouped: [(group: Group, items: [MigraineTrigger])] {
        [
            (.lifestyle, lifestyle),
            (.hormonal, hormonal),
            (.dietary, dietary),
            (.sensory, sensory),
            (.weather, weather),
            (.physicalMedication, physicalMedication),
            (.other, otherCategory)
        ]
    }

    /// Get all cases for a specific group.
    static func cases(for group: Group) -> [MigraineTrigger] {
        switch group {
        case .lifestyle: return lifestyle
        case .hormonal: return hormonal
        case .dietary: return dietary
        case .sensory: return sensory
        case .weather: return weather
        case .physicalMedication: return physicalMedication
        case .other: return otherCategory
        }
    }

    // MARK: Concrete lists per group
    static var lifestyle: [MigraineTrigger] {
        [.stress, .lackOfSleep, .oversleeping, .skippedMeals, .dehydration,
         .jetLag, .shiftWork, .screenTimeFlicker, .postureNeckTension, .bruxismTeethGrinding]
    }
    static var hormonal: [MigraineTrigger] { [.hormonalFluctuation] }
    static var dietary: [MigraineTrigger] {
        [.alcoholRedWine, .caffeineExcess, .caffeineWithdrawal, .chocolate,
         .agedCheese, .processedMeatsNitrates, .msg, .aspartame]
    }
    static var sensory: [MigraineTrigger] { [.brightLightGlare, .loudNoise, .strongOdors] }
    static var weather: [MigraineTrigger] { [.barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind] }
    static var physicalMedication: [MigraineTrigger] { [.intenseExercise, .certainMedications, .medicationOveruse] }
    static var otherCategory: [MigraineTrigger] { [.other] }
}

// MARK: - Presentation helpers

public extension MigraineTrigger {
    enum Group: String, CaseIterable { case lifestyle, hormonal, dietary, sensory, weather, physicalMedication, other }

    var group: Group {
        switch self {
        case .stress, .lackOfSleep, .oversleeping, .skippedMeals, .dehydration, .jetLag, .shiftWork, .screenTimeFlicker, .postureNeckTension, .bruxismTeethGrinding:
            return .lifestyle
        case .hormonalFluctuation:
            return .hormonal
        case .alcoholRedWine, .caffeineExcess, .caffeineWithdrawal, .chocolate, .agedCheese, .processedMeatsNitrates, .msg, .aspartame:
            return .dietary
        case .brightLightGlare, .loudNoise, .strongOdors:
            return .sensory
        case .barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind:
            return .weather
        case .intenseExercise, .certainMedications, .medicationOveruse:
            return .physicalMedication
        case .other:
            return .other
        }
    }

    /// Human-friendly label for UI.
    var displayName: String {
        switch self {
        case .stress: return "Stress"
        case .lackOfSleep: return "Lack of sleep"
        case .oversleeping: return "Oversleeping"
        case .skippedMeals: return "Skipped meals / hunger"
        case .dehydration: return "Dehydration"
        case .jetLag: return "Jet lag"
        case .shiftWork: return "Shifted Work Hours"
        case .screenTimeFlicker: return "Screen time / flicker"
        case .postureNeckTension: return "Poor posture / neck tension"
        case .bruxismTeethGrinding: return "Teeth grinding (bruxism)"

        case .hormonalFluctuation: return "Hormonal changes"

        case .alcoholRedWine: return "Alcohol (esp. red wine)"
        case .caffeineExcess: return "Too much caffeine"
        case .caffeineWithdrawal: return "Caffeine withdrawal"
        case .chocolate: return "Chocolate"
        case .agedCheese: return "Aged cheeses"
        case .processedMeatsNitrates: return "Processed meats / nitrates"
        case .msg: return "MSG"
        case .aspartame: return "Aspartame"

        case .brightLightGlare: return "Bright light / glare"
        case .loudNoise: return "Loud noise"
        case .strongOdors: return "Strong odors / perfume"

        case .barometricPressureChange: return "Barometric pressure changes"
        case .highHumidity: return "High humidity"
        case .heatExtreme: return "High heat"
        case .coldExtreme: return "Cold exposure"
        case .stormsWind: return "Storms / wind"

        case .intenseExercise: return "Intense exercise"
        case .certainMedications: return "Certain medications"
        case .medicationOveruse: return "Medication overuse"

        case .other: return "Other"
        }
    }
}

// MARK: - Suggested ordering for grids

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
