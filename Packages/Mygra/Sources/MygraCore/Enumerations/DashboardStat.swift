//
//  DashboardStat.swift
//  MygraCore
//
//  The health statistics the Today card can show, with the user's visibility and
//  ordering preferences behind the `KeyValueStoring` seam so both are host-tested.
//  Colors live in MygraDesignSystem.
//

import Foundation

nonisolated public enum DashboardStat: String, CaseIterable, Codable, Identifiable, Sendable {
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

    // MARK: - Visibility

    /// Whether the user has this stat switched on (falling back to the default).
    public func isVisible(in store: any KeyValueStoring) -> Bool {
        guard store.object(forKey: storageKey) != nil else { return defaultVisibility }
        return store.bool(forKey: storageKey)
    }

    // MARK: - Order

    /// The order before the user rearranges anything: declaration order of the
    /// HealthKit-backed tiles.
    public static var defaultOrder: [DashboardStat] { healthKitStats }

    /// Decodes a saved order, dropping unknown values and backfilling any stats added
    /// since it was written, so a stale preference never hides a tile.
    public static func order(from data: Data?) -> [DashboardStat] {
        guard let data, let saved = try? JSONDecoder().decode([DashboardStat].self, from: data) else {
            return defaultOrder
        }
        var result = saved.filter { defaultOrder.contains($0) }.uniqued()
        for stat in defaultOrder where !result.contains(stat) {
            result.append(stat)
        }
        return result
    }

    /// Encodes an order for storage (nil only if JSON encoding fails, which it can't
    /// for a raw-value enum).
    public static func encodeOrder(_ order: [DashboardStat]) -> Data? {
        try? JSONEncoder().encode(order)
    }

    /// The saved tile order through the key-value seam.
    public static func loadOrder(from store: any KeyValueStoring) -> [DashboardStat] {
        order(from: store.data(forKey: AppStorageKeys.dashboardStatOrder))
    }

    /// Persists a tile order through the key-value seam.
    public static func saveOrder(_ order: [DashboardStat], to store: any KeyValueStoring) {
        store.set(encodeOrder(order), forKey: AppStorageKeys.dashboardStatOrder)
    }

    /// The HealthKit tiles the Today card shows, in the user's order.
    public static func visibleStats(in store: any KeyValueStoring) -> [DashboardStat] {
        loadOrder(from: store).filter { $0.isVisible(in: store) }
    }
}
