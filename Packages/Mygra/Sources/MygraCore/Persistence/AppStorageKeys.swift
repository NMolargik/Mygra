//
//  AppStorageKeys.swift
//  MygraCore
//

import Foundation

nonisolated public enum AppStorageKeys {
    // MARK: - Global Settings
    public static let useMetricUnits = "useMetricUnits"
    public static let useDayMonthYearDates = "useDayMonthYearDates"
    public static let bgWeatherTaskScheduled = "bgWeatherTaskScheduled"
    public static let isOnboardingComplete = "isOnboardingComplete"
    public static let hasPromptedForFifthReview = "MigraineManager.hasPromptedForFifthReview"

    // MARK: - Dashboard Stat Visibility
    public static let showWaterStat = "showWaterStat"
    public static let showSleepStat = "showSleepStat"
    public static let showFoodStat = "showFoodStat"
    public static let showCaffeineStat = "showCaffeineStat"
    public static let showStepsStat = "showStepsStat"
    public static let showHeartRateStat = "showHeartRateStat"
    public static let showOxygenStat = "showOxygenStat"
    public static let showGlucoseStat = "showGlucoseStat"
    public static let showTriggersStat = "showTriggersStat"

    // MARK: - Dashboard Stat Order
    /// JSON-encoded `[DashboardStat]` giving the user's tile order on the Today card.
    public static let dashboardStatOrder = "dashboardStatOrder"
}
