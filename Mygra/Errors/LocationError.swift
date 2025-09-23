//
//  LocationError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum LocationError: LocalizedError {
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
}
