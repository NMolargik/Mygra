//
//  UserError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum UserError: LocalizedError, CustomStringConvertible {
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case notFound
    case cloudRestoreTimedOut

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let underlying):
            return "Failed to fetch user: \(underlying.localizedDescription)"
        case .saveFailed(let underlying):
            return "Failed to save user: \(underlying.localizedDescription)"
        case .deleteFailed(let underlying):
            return "Failed to delete user: \(underlying.localizedDescription)"
        case .notFound:
            return "No user found."
        case .cloudRestoreTimedOut:
            return "Timed out waiting for iCloud to restore user."
        }
    }

    var description: String { errorDescription ?? String(describing: self) }
}
