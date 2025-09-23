//
//  MigraineError.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

enum MigraineError: LocalizedError, Sendable {
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let underlying):
            return "Failed to fetch migraines: \(underlying.localizedDescription)"
        case .saveFailed(let underlying):
            return "Failed to save migraines: \(underlying.localizedDescription)"
        case .deleteFailed(let underlying):
            return "Failed to delete migraine: \(underlying.localizedDescription)"
        }
    }
}
