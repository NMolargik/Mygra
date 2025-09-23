//
//  NotificationError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum NotificationError: LocalizedError {
    case authorizationRequestFailed(underlying: Error)
    case authorizationDenied
    case schedulingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .authorizationRequestFailed(let underlying):
            return "Failed to request notification authorization: \(underlying.localizedDescription)"
        case .authorizationDenied:
            return "User denied notification authorization."
        case .schedulingFailed(let underlying):
            return "Failed to schedule notification: \(underlying.localizedDescription)"
        }
    }
}
