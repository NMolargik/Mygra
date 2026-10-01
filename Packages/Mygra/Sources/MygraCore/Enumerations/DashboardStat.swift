//
//  DashboardStat.swift
//  MygraCore
//
//  The health statistics the Today card can show. Colors live in MygraDesignSystem.
//

import Foundation

nonisolated public enum DashboardStat: String, CaseIterable, Identifiable, Sendable {
    // Core stats (shown by default)
    case water
    case sleep
    case food
    case caffeine

    // Additional HealthKit stats
    case steps
    case restingHeartRate
    case bloodOxygen
    case bloodGlucose

    // Personalized insight stat
    case topTriggers

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .water: return String(localized: "Water")
        case .sleep: return String(localized: "Sleep")
        case .food: return String(localized: "Food")
        case .caffeine: return String(localized: "Caffeine")
        case .steps: return String(localized: "Steps")
        case .restingHeartRate: return String(localized: "Heart Rate")
        case .bloodOxygen: return String(localized: "Blood Oxygen")
        case .bloodGlucose: return String(localized: "Glucose")
        case .topTriggers: return String(localized: "Top Triggers")
        }
    }

    public var systemImage: String {
        switch self {
        case .water: return "drop.fill"
        case .sleep: return "bed.double.fill"
        case .food: return "fork.knife"
        case .caffeine: return "cup.and.saucer.fill"
        case .steps: return "figure.walk"
        case .restingHeartRate: return "heart.fill"
        case .bloodOxygen: return "lungs.fill"
        case .bloodGlucose: return "cross.case.fill"
        case .topTriggers: return "exclamationmark.triangle.fill"
        }
    }

    /// The AppStorage key for this stat's visibility toggle.
    public var storageKey: String {
        switch self {
        case .water: return AppStorageKeys.showWaterStat
        case .sleep: return AppStorageKeys.showSleepStat
        case .food: return AppStorageKeys.showFoodStat
        case .caffeine: return AppStorageKeys.showCaffeineStat
        case .steps: return AppStorageKeys.showStepsStat
        case .restingHeartRate: return AppStorageKeys.showHeartRateStat
        case .bloodOxygen: return AppStorageKeys.showOxygenStat
        case .bloodGlucose: return AppStorageKeys.showGlucoseStat
        case .topTriggers: return AppStorageKeys.showTriggersStat
        }
    }

    /// Whether this stat is visible before the user changes anything.
    public var defaultVisibility: Bool {
        switch self {
        case .water, .sleep, .food, .caffeine: return true
        case .steps, .restingHeartRate, .bloodOxygen, .bloodGlucose, .topTriggers: return false
        }
    }

    /// Stats that come from HealthKit (vs computed stats like `topTriggers`).
    public static var healthKitStats: [DashboardStat] {
        [.water, .sleep, .food, .caffeine, .steps, .restingHeartRate, .bloodOxygen, .bloodGlucose]
    }

    /// Stats computed from migraine data.
    public static var insightStats: [DashboardStat] {
        [.topTriggers]
    }
}
