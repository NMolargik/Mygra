//
//  InsightError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum InsightError: LocalizedError, Equatable {
    case refreshFailed(underlying: Error)
    case generateAllFailed(underlying: Error)
    case trendsFailed(underlying: Error)
    case triggersFailed(underlying: Error)
    case foodsFailed(underlying: Error)
    case intakeFailed(underlying: Error)
    case sleepFailed(underlying: Error)
    case weatherFailed(underlying: Error)
    case phasesFailed(underlying: Error)
    case intelligenceUnavailable
    case intelligenceAnalysisFailed(underlying: Error)
    case chatStartFailed(underlying: Error)
    case chatSendFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .refreshFailed:
            return "Failed to refresh insights."
        case .generateAllFailed:
            return "Failed to generate insights."
        case .trendsFailed:
            return "Failed to generate migraine trends."
        case .triggersFailed:
            return "Failed to generate trigger insights."
        case .foodsFailed:
            return "Failed to generate food insights."
        case .intakeFailed:
            return "Failed to generate intake insights."
        case .sleepFailed:
            return "Failed to generate sleep insights."
        case .weatherFailed:
            return "Failed to generate weather insights."
        case .phasesFailed:
            return "Failed to generate menstrual phase insights."
        case .intelligenceUnavailable:
            return "Apple Intelligence is not available on this device."
        case .intelligenceAnalysisFailed:
            return "Failed to analyze migraine with Intelligence."
        case .chatStartFailed:
            return "Failed to start counselor chat."
        case .chatSendFailed:
            return "Failed to send counselor message."
        }
    }

    static func == (lhs: InsightError, rhs: InsightError) -> Bool {
        switch (lhs, rhs) {
        case (.refreshFailed(let le), .refreshFailed(let re)),
             (.generateAllFailed(let le), .generateAllFailed(let re)),
             (.trendsFailed(let le), .trendsFailed(let re)),
             (.triggersFailed(let le), .triggersFailed(let re)),
             (.foodsFailed(let le), .foodsFailed(let re)),
             (.intakeFailed(let le), .intakeFailed(let re)),
             (.sleepFailed(let le), .sleepFailed(let re)),
             (.weatherFailed(let le), .weatherFailed(let re)),
             (.phasesFailed(let le), .phasesFailed(let re)),
             (.intelligenceAnalysisFailed(let le), .intelligenceAnalysisFailed(let re)),
             (.chatStartFailed(let le), .chatStartFailed(let re)),
             (.chatSendFailed(let le), .chatSendFailed(let re)):
            let ln = le as NSError
            let rn = re as NSError
            return ln.domain == rn.domain && ln.code == rn.code
        case (.intelligenceUnavailable, .intelligenceUnavailable):
            return true
        default:
            return false
        }
    }
}
