//
//  PersistenceError.swift
//  MygraCore
//
//  The typed failure for the whole persistence boundary. Repositories and use-cases
//  declare `throws(PersistenceError)` so view models catch a concrete, Equatable error.
//

import Foundation

nonisolated public enum PersistenceError: Error, Equatable, LocalizedError, Sendable {
    case fetchFailed(String)
    case saveFailed(String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let detail): String(localized: "Couldn't load your migraine data. (\(detail))")
        case .saveFailed(let detail): String(localized: "Couldn't save your changes. (\(detail))")
        case .notFound: String(localized: "That record no longer exists.")
        }
    }
}
