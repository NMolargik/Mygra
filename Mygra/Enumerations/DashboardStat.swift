//
//  DashboardStat.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import Foundation
import SwiftUI

/// Represents the various health statistics that can be displayed on the Today card.
enum DashboardStat: String, CaseIterable, Identifiable, Sendable {
    // Core stats (currently shown by default)
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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .sleep: return "Sleep"
        case .food: return "Food"
        case .caffeine: return "Caffeine"
        case .steps: return "Steps"
        case .restingHeartRate: return "Heart Rate"
        case .bloodOxygen: return "Blood Oxygen"
        case .bloodGlucose: return "Glucose"
        case .topTriggers: return "Top Triggers"
        }
    }

    var systemImage: String {
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

    var color: Color {
        switch self {
        case .water: return .blue
        case .sleep: return .indigo
        case .food: return .orange
        case .caffeine: return .brown
        case .steps: return .green
        case .restingHeartRate: return .red
        case .bloodOxygen: return .cyan
        case .bloodGlucose: return .mint
        case .topTriggers: return .purple
        }
    }

    /// The AppStorage key for this stat's visibility toggle.
    var storageKey: String {
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

    /// Whether this stat should be visible by default.
    var defaultVisibility: Bool {
        switch self {
        case .water, .sleep, .food, .caffeine:
            return true  // Original 4 stats default to visible
        case .steps, .restingHeartRate, .bloodOxygen, .bloodGlucose, .topTriggers:
            return false // New stats default to hidden
        }
    }

    /// Stats that come from HealthKit (vs computed stats like topTriggers).
    static var healthKitStats: [DashboardStat] {
        [.water, .sleep, .food, .caffeine, .steps, .restingHeartRate, .bloodOxygen, .bloodGlucose]
    }

    /// Stats that are computed from migraine data.
    static var insightStats: [DashboardStat] {
        [.topTriggers]
    }
}
