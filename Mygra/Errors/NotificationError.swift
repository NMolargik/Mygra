//
//  NotificationError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum NotificationError: Error, LocalizedError, Equatable {
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

    static func == (lhs: NotificationError, rhs: NotificationError) -> Bool {
        switch (lhs, rhs) {
        case (.authorizationDenied, .authorizationDenied):
            return true
        case let (.authorizationRequestFailed(l), .authorizationRequestFailed(r)):
            return NotificationError.compareErrors(l, r)
        case let (.schedulingFailed(l), .schedulingFailed(r)):
            return NotificationError.compareErrors(l, r)
        default:
            return false
        }
    }

    /// Best-effort comparison for underlying Error values.
    /// Compares NSError domain/code and localizedDescription to avoid leaking implementation details.
    private static func compareErrors(_ lhs: Error, _ rhs: Error) -> Bool {
        let ln = lhs as NSError
        let rn = rhs as NSError
        if ln.domain == rn.domain && ln.code == rn.code {
            return true
        }
        return ln.localizedDescription == rn.localizedDescription
    }
}
