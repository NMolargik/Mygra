//
//  MigraineTrigger.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation

/// Common migraine triggers captured as a selectable grid in the UI.
/// This list focuses on broadly reported triggers across reputable sources
/// Sources referenced when curating categories/cases: American Migraine Foundation, Mayo Clinic,
/// Cleveland Clinic, NHS, Migraine Trust, National Migraine Centre.
/// Cases are intentionally granular enough for analytics without becoming unmanageably specific.
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
    case relaxationAfterStress     // "let-down" after stress
    case motionSickness
    case anxietyDepression

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
    case alcoholBeerSpirits

    // MARK: - Sensory / Environmental (non-weather)
    case brightLightGlare
    case loudNoise
    case strongOdors
    case flashingLightsStrobe
    case eyeStrainBlueLight

    // MARK: - Weather / Atmosphere
    case barometricPressureChange
    case highHumidity
    case heatExtreme
    case coldExtreme
    case stormsWind
    case highAltitudeCabinPressure

    // MARK: - Physical exertion
    case intenseExercise
    case sexualActivity
    case valsalvaCoughSneeze
    case postureNeckTension
    case bruxismTeethGrinding

    // MARK: - Substances & Air Quality
    case tobaccoNicotine
    case smokeExposure
    case allergensPollen
    case airPollution
    case indoorMoldDamp

    // MARK: - Medications
    case certainMedications
    case medicationOveruse

    // MARK: - Catch-all
    case other
    
    static var grouped: [(group: Group, items: [MigraineTrigger])] {
        [
            (.routine, routine),
            (.psychological, psychological),
            (.dietaryHydration, dietaryHydration),
            (.substances, substances),
            (.sensory, sensory),
            (.airQuality, airQuality),
            (.weather, weather),
            (.physicalStrain, physicalStrain),
            (.hormonal, hormonal),
            (.medications, medications),
            (.other, otherCategory)
        ]
    }

    /// Get all cases for a specific group.
    static func cases(for group: Group) -> [MigraineTrigger] {
        switch group {
        case .routine: return routine
        case .psychological: return psychological
        case .dietaryHydration: return dietaryHydration
        case .substances: return substances
        case .sensory: return sensory
        case .airQuality: return airQuality
        case .weather: return weather
        case .physicalStrain: return physicalStrain
        case .hormonal: return hormonal
        case .medications: return medications
        case .other: return otherCategory
        }
    }

    // MARK: Concrete lists per group
    static var routine: [MigraineTrigger] {
        [.lackOfSleep, .oversleeping, .jetLag, .shiftWork, .skippedMeals, .relaxationAfterStress]
    }
    static var psychological: [MigraineTrigger] {
        [.stress, .anxietyDepression]
    }
    static var dietaryHydration: [MigraineTrigger] {
        [.dehydration, .alcoholRedWine, .alcoholBeerSpirits, .caffeineExcess, .caffeineWithdrawal,
         .chocolate, .agedCheese, .processedMeatsNitrates, .msg, .aspartame]
    }
    static var substances: [MigraineTrigger] {
        [.tobaccoNicotine]
    }
    static var sensory: [MigraineTrigger] {
        [.brightLightGlare, .flashingLightsStrobe, .loudNoise, .strongOdors, .screenTimeFlicker, .eyeStrainBlueLight]
    }
    static var airQuality: [MigraineTrigger] {
        [.smokeExposure, .allergensPollen, .airPollution, .indoorMoldDamp]
    }
    static var weather: [MigraineTrigger] {
        [.barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind, .highAltitudeCabinPressure]
    }
    static var physicalStrain: [MigraineTrigger] {
        [.intenseExercise, .sexualActivity, .valsalvaCoughSneeze, .postureNeckTension, .bruxismTeethGrinding, .motionSickness]
    }
    static var hormonal: [MigraineTrigger] { [.hormonalFluctuation] }
    static var medications: [MigraineTrigger] { [.certainMedications, .medicationOveruse] }
    static var otherCategory: [MigraineTrigger] { [.other] }
    
    enum Group: String, CaseIterable {
        case routine            // schedule & behavior patterns
        case psychological      // emotional and cognitive factors
        case dietaryHydration   // food, drink, meal timing, hydration
        case substances         // nicotine/tobacco and other non-food exposures
        case sensory            // light, sound, odors, screen/visual strain
        case airQuality         // smoke, allergens, pollution, indoor air
        case weather            // pressure, humidity, temperature, storms, altitude
        case physicalStrain     // exertion, posture/tension, Valsalva-like strain, motion
        case hormonal           // menstrual-related and other hormone changes
        case medications        // specific meds and medication overuse
        case other              // free-form user input
      
        /// Human-friendly category name for use in UI section headers
        var displayName: String {
            switch self {
            case .routine: return "Routine & Sleep"
            case .psychological: return "Psychological"
            case .dietaryHydration: return "Diet & Hydration"
            case .substances: return "Substances"
            case .sensory: return "Sensory"
            case .airQuality: return "Air Quality & Allergens"
            case .weather: return "Weather & Atmosphere"
            case .physicalStrain: return "Physical Strain"
            case .hormonal: return "Hormonal"
            case .medications: return "Medications"
            case .other: return "Other"
            }
        }
    }

    var group: Group {
        switch self {
        // routine
        case .lackOfSleep, .oversleeping, .jetLag, .shiftWork, .skippedMeals, .relaxationAfterStress:
            return .routine
        // psychological
        case .stress, .anxietyDepression:
            return .psychological
        // dietary & hydration
        case .dehydration, .alcoholRedWine, .alcoholBeerSpirits, .caffeineExcess, .caffeineWithdrawal, .chocolate,
             .agedCheese, .processedMeatsNitrates, .msg, .aspartame:
            return .dietaryHydration
        // substances
        case .tobaccoNicotine:
            return .substances
        // sensory
        case .brightLightGlare, .flashingLightsStrobe, .loudNoise, .strongOdors, .screenTimeFlicker, .eyeStrainBlueLight:
            return .sensory
        // air quality
        case .smokeExposure, .allergensPollen, .airPollution, .indoorMoldDamp:
            return .airQuality
        // weather
        case .barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind, .highAltitudeCabinPressure:
            return .weather
        // physical strain
        case .intenseExercise, .sexualActivity, .valsalvaCoughSneeze, .postureNeckTension, .bruxismTeethGrinding, .motionSickness:
            return .physicalStrain
        // hormonal
        case .hormonalFluctuation:
            return .hormonal
        // medications
        case .certainMedications, .medicationOveruse:
            return .medications
        // other
        case .other:
            return .other
        }
    }
    
    

    /// Human-friendly label for UI.
    var displayName: String {
        switch self {
        // routine
        case .lackOfSleep: return "Lack of sleep"
        case .oversleeping: return "Oversleeping"
        case .jetLag: return "Jet lag"
        case .shiftWork: return "Shifted work hours"
        case .skippedMeals: return "Skipped meals / hunger"
        case .relaxationAfterStress: return "Let-down after stress"
        
        // psychological
        case .stress: return "Stress"
        case .anxietyDepression: return "Anxiety / depression"
        
        // dietary & hydration
        case .dehydration: return "Dehydration"
        case .alcoholRedWine: return "Alcohol (red wine)"
        case .alcoholBeerSpirits: return "Alcohol (beer / spirits)"
        case .caffeineExcess: return "Too much caffeine"
        case .caffeineWithdrawal: return "Caffeine withdrawal"
        case .chocolate: return "Chocolate"
        case .agedCheese: return "Aged cheeses"
        case .processedMeatsNitrates: return "Processed meats / nitrates"
        case .msg: return "MSG"
        case .aspartame: return "Aspartame"
        
        // substances
        case .tobaccoNicotine: return "Tobacco / nicotine"
        
        // sensory
        case .brightLightGlare: return "Bright light / glare"
        case .flashingLightsStrobe: return "Flashing / strobe lights"
        case .loudNoise: return "Loud noise"
        case .strongOdors: return "Strong odors / perfume"
        case .screenTimeFlicker: return "Screen time / flicker"
        case .eyeStrainBlueLight: return "Eye strain / blue light"
        
        // air quality
        case .smokeExposure: return "Smoke exposure"
        case .allergensPollen: return "Allergens / pollen"
        case .airPollution: return "Air pollution"
        case .indoorMoldDamp: return "Indoor mold / dampness"
        
        // weather
        case .barometricPressureChange: return "Barometric pressure changes"
        case .highHumidity: return "High humidity"
        case .heatExtreme: return "High heat"
        case .coldExtreme: return "Cold exposure"
        case .stormsWind: return "Storms / wind"
        case .highAltitudeCabinPressure: return "High altitude / cabin pressure"
        
        // physical strain
        case .intenseExercise: return "Intense exercise"
        case .sexualActivity: return "Sexual activity"
        case .valsalvaCoughSneeze: return "Coughing / sneezing strain"
        case .postureNeckTension: return "Poor posture / neck tension"
        case .bruxismTeethGrinding: return "Teeth grinding (bruxism)"
        case .motionSickness: return "Motion sickness"
        
        // hormonal
        case .hormonalFluctuation: return "Hormonal changes"
        
        // medications
        case .certainMedications: return "Certain medications"
        case .medicationOveruse: return "Medication overuse"
        
        // other
        case .other: return "Other"
        }
    }
}
