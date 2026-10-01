//
//  InsightCategory.swift
//  MygraCore
//

import Foundation

nonisolated public enum InsightCategory: String, Hashable, Sendable, CaseIterable {
    case trendFrequency
    case trendSeverity
    case trendDuration
    case triggers
    case foods
    case intakeHydration
    case intakeSleep
    case intakeNutrition
    case sleepAssociation
    case weatherAssociation
    case generative
    case biometrics
    case intensityPattern
    case intensityPeakTiming
    case tagFrequency
    case tagSeverityCorrelation
}
