//
//  InsightCategory.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation

enum InsightCategory: String, Hashable {
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
    // Intensity tracking insights
    case intensityPattern
    case intensityPeakTiming
    // Tag insights
    case tagFrequency
    case tagSeverityCorrelation
}
