//
//  HealthError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum HealthError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied
    case authorizationFailed(underlying: Error)
    case readRequestStatusFailed(underlying: Error)
    case shareRequestStatusFailed(underlying: Error)
    case snapshotFailed(underlying: Error)
    case saveFailed(kind: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is unavailable on this device."
        case .authorizationDenied:
            return "Health access was not authorized."
        case .authorizationFailed:
            return "Failed to request Health authorization."
        case .readRequestStatusFailed:
            return "Failed to obtain Health read request status."
        case .shareRequestStatusFailed:
            return "Failed to obtain Health share request status."
        case .snapshotFailed:
            return "Failed to fetch Health snapshot."
        case .saveFailed(let kind, _):
            return "Failed to save \(kind) to Health."
        }
    }

    var failureReason: String? {
        switch self {
        case .authorizationFailed(let underlying),
             .readRequestStatusFailed(let underlying),
             .shareRequestStatusFailed(let underlying),
             .snapshotFailed(let underlying),
             .saveFailed(_, let underlying):
            return underlying.localizedDescription
        default:
            return nil
        }
    }
}
