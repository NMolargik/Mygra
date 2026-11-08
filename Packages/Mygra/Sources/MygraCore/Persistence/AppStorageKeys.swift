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
    public static let hasPromptedForExportReview = "Review.hasPromptedAfterFirstExport"

    // MARK: - Mygra Plus
    /// Cached grandfather verdict (absent = never checked).
    public static let plusGrandfathered = "Plus.grandfathered"
    public static let plusEarlySupporterThanksShown = "Plus.earlySupporterThanksShown"

    // MARK: - Clinical
    /// JSON `[String: Int]` of the overuse level already notified per class.
    public static let medicationAlertLevels = "Medication.alertLevels"
    /// JSON `ClinicalAssessment` (latest MIDAS / HIT-6 answers).
    public static let clinicalAssessment = "Clinical.assessment"
    public static let reportWindowMonths = "Clinical.reportWindowMonths"
    public static let reportIncludeName = "Clinical.reportIncludeName"
    public static let reportIncludeBirthday = "Clinical.reportIncludeBirthday"
    public static let reportIncludeHealthProfile = "Clinical.reportIncludeHealthProfile"

    // MARK: - Attack Mode
    /// Whether ending an attack schedules the gentle finish-logging prompt (default on).
    public static let attackFinishPromptEnabled = "AttackMode.finishPromptEnabled"
    /// Minutes after End Attack before the prompt (default 120).
    public static let attackFinishPromptDelayMinutes = "AttackMode.finishPromptDelayMinutes"
    /// JSON `[FinishItem]` of ended attacks still waiting to be finished.
    public static let attackPendingFinishItems = "AttackMode.pendingFinishItems"

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
