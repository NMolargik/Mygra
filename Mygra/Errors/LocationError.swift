//
//  LocationError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum LocationError: LocalizedError, Equatable {
    case notAuthorized
    case requestInProgress
    case updateFailed(underlying: Error)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access is not authorized."
        case .requestInProgress:
            return "A location request is already in progress."
        case .updateFailed:
            return "Failed to obtain a location update."
        case .unavailable:
            return "Location services are unavailable."
        }
    }

    static func == (lhs: LocationError, rhs: LocationError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthorized, .notAuthorized),
             (.requestInProgress, .requestInProgress),
             (.unavailable, .unavailable):
            return true
        case (.updateFailed(let le), .updateFailed(let re)):
            let ln = le as NSError
            let rn = re as NSError
            return ln.domain == rn.domain && ln.code == rn.code
        default:
            return false
        }
    }
}
