//
//  MigraineTrigger.swift
//  MygraCore
//
//  Common migraine triggers captured as a selectable list in the UI. The list focuses
//  on broadly reported triggers across reputable sources (American Migraine Foundation,
//  Mayo Clinic, Cleveland Clinic, NHS, Migraine Trust, National Migraine Centre) and is
//  granular enough for analytics without becoming unmanageable.
//

import Foundation

nonisolated public enum MigraineTrigger: String, Codable, CaseIterable, Hashable, Sendable {
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
    case hormonalFluctuation

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

    // MARK: - Groups

    public enum Group: String, CaseIterable, Sendable, Hashable {
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

        /// Human-friendly category name for UI section headers.
        public var displayName: String {
            switch self {
            case .routine: return String(localized: "Routine & Sleep")
            case .psychological: return String(localized: "Psychological")
            case .dietaryHydration: return String(localized: "Diet & Hydration")
            case .substances: return String(localized: "Substances")
            case .sensory: return String(localized: "Sensory")
            case .airQuality: return String(localized: "Air Quality & Allergens")
            case .weather: return String(localized: "Weather & Atmosphere")
            case .physicalStrain: return String(localized: "Physical Strain")
            case .hormonal: return String(localized: "Hormonal")
            case .medications: return String(localized: "Medications")
            case .other: return String(localized: "Other")
            }
        }

        /// The triggers in this group, in display order.
        public var triggers: [MigraineTrigger] {
            switch self {
            case .routine:
                return [.lackOfSleep, .oversleeping, .jetLag, .shiftWork, .skippedMeals, .relaxationAfterStress]
            case .psychological:
                return [.stress, .anxietyDepression]
            case .dietaryHydration:
                return [.dehydration, .alcoholRedWine, .alcoholBeerSpirits, .caffeineExcess, .caffeineWithdrawal,
                        .chocolate, .agedCheese, .processedMeatsNitrates, .msg, .aspartame]
            case .substances:
                return [.tobaccoNicotine]
            case .sensory:
                return [.brightLightGlare, .flashingLightsStrobe, .loudNoise, .strongOdors, .screenTimeFlicker, .eyeStrainBlueLight]
            case .airQuality:
                return [.smokeExposure, .allergensPollen, .airPollution, .indoorMoldDamp]
            case .weather:
                return [.barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind, .highAltitudeCabinPressure]
            case .physicalStrain:
                return [.intenseExercise, .sexualActivity, .valsalvaCoughSneeze, .postureNeckTension, .bruxismTeethGrinding, .motionSickness]
            case .hormonal:
                return [.hormonalFluctuation]
            case .medications:
                return [.certainMedications, .medicationOveruse]
            case .other:
                return [.other]
            }
        }
    }

    /// Every group with its triggers, in display order.
    public static var grouped: [(group: Group, items: [MigraineTrigger])] {
        Group.allCases.map { ($0, $0.triggers) }
    }

    /// The triggers in `group`, filtered by a case-insensitive search on the display name.
    /// An empty/whitespace query returns the whole group.
    public static func triggers(in group: Group, matching query: String) -> [MigraineTrigger] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return group.triggers }
        let lower = trimmed.lowercased()
        return group.triggers.filter { $0.displayName.lowercased().contains(lower) }
    }

    public var group: Group {
        switch self {
        case .lackOfSleep, .oversleeping, .jetLag, .shiftWork, .skippedMeals, .relaxationAfterStress:
            return .routine
        case .stress, .anxietyDepression:
            return .psychological
        case .dehydration, .alcoholRedWine, .alcoholBeerSpirits, .caffeineExcess, .caffeineWithdrawal, .chocolate,
             .agedCheese, .processedMeatsNitrates, .msg, .aspartame:
            return .dietaryHydration
        case .tobaccoNicotine:
            return .substances
        case .brightLightGlare, .flashingLightsStrobe, .loudNoise, .strongOdors, .screenTimeFlicker, .eyeStrainBlueLight:
            return .sensory
        case .smokeExposure, .allergensPollen, .airPollution, .indoorMoldDamp:
            return .airQuality
        case .barometricPressureChange, .highHumidity, .heatExtreme, .coldExtreme, .stormsWind, .highAltitudeCabinPressure:
            return .weather
        case .intenseExercise, .sexualActivity, .valsalvaCoughSneeze, .postureNeckTension, .bruxismTeethGrinding, .motionSickness:
            return .physicalStrain
        case .hormonalFluctuation:
            return .hormonal
        case .certainMedications, .medicationOveruse:
            return .medications
        case .other:
            return .other
        }
    }

    /// Human-friendly label for UI.
    public var displayName: String {
        switch self {
        case .lackOfSleep: return String(localized: "Lack of sleep")
        case .oversleeping: return String(localized: "Oversleeping")
        case .jetLag: return String(localized: "Jet lag")
        case .shiftWork: return String(localized: "Shifted work hours")
        case .skippedMeals: return String(localized: "Skipped meals / hunger")
        case .relaxationAfterStress: return String(localized: "Let-down after stress")
        case .stress: return String(localized: "Stress")
        case .anxietyDepression: return String(localized: "Anxiety / depression")
        case .dehydration: return String(localized: "Dehydration")
        case .alcoholRedWine: return String(localized: "Alcohol (red wine)")
        case .alcoholBeerSpirits: return String(localized: "Alcohol (beer / spirits)")
        case .caffeineExcess: return String(localized: "Too much caffeine")
        case .caffeineWithdrawal: return String(localized: "Caffeine withdrawal")
        case .chocolate: return String(localized: "Chocolate")
        case .agedCheese: return String(localized: "Aged cheeses")
        case .processedMeatsNitrates: return String(localized: "Processed meats / nitrates")
        case .msg: return String(localized: "MSG")
        case .aspartame: return String(localized: "Aspartame")
        case .tobaccoNicotine: return String(localized: "Tobacco / nicotine")
        case .brightLightGlare: return String(localized: "Bright light / glare")
        case .flashingLightsStrobe: return String(localized: "Flashing / strobe lights")
        case .loudNoise: return String(localized: "Loud noise")
        case .strongOdors: return String(localized: "Strong odors / perfume")
        case .screenTimeFlicker: return String(localized: "Screen time / flicker")
        case .eyeStrainBlueLight: return String(localized: "Eye strain / blue light")
        case .smokeExposure: return String(localized: "Smoke exposure")
        case .allergensPollen: return String(localized: "Allergens / pollen")
        case .airPollution: return String(localized: "Air pollution")
        case .indoorMoldDamp: return String(localized: "Indoor mold / dampness")
        case .barometricPressureChange: return String(localized: "Barometric pressure changes")
        case .highHumidity: return String(localized: "High humidity")
        case .heatExtreme: return String(localized: "High heat")
        case .coldExtreme: return String(localized: "Cold exposure")
        case .stormsWind: return String(localized: "Storms / wind")
        case .highAltitudeCabinPressure: return String(localized: "High altitude / cabin pressure")
        case .intenseExercise: return String(localized: "Intense exercise")
        case .sexualActivity: return String(localized: "Sexual activity")
        case .valsalvaCoughSneeze: return String(localized: "Coughing / sneezing strain")
        case .postureNeckTension: return String(localized: "Poor posture / neck tension")
        case .bruxismTeethGrinding: return String(localized: "Teeth grinding (bruxism)")
        case .motionSickness: return String(localized: "Motion sickness")
        case .hormonalFluctuation: return String(localized: "Hormonal changes")
        case .certainMedications: return String(localized: "Certain medications")
        case .medicationOveruse: return String(localized: "Medication overuse")
        case .other: return String(localized: "Other")
        }
    }
}
