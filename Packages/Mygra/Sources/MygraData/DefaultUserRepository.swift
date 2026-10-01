//
//  DefaultUserRepository.swift
//  MygraData
//
//  The SwiftData-backed `UserRepository`. Folds duplicate profiles left by CloudKit
//  merges into one on every read.
//

import Foundation
import SwiftData
import MygraCore
import os

@MainActor
public final class DefaultUserRepository: UserRepository {

    private let container: ModelContainer
    private let changeCenter: MigraineChangeCenter?

    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer, changeCenter: MigraineChangeCenter? = nil) {
        self.container = container
        self.changeCenter = changeCenter
    }

    public func currentUser() throws(PersistenceError) -> User? {
        let fetched: [User]
        do {
            fetched = try context.fetch(FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        } catch {
            Log.user.error("User fetch failed: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(error.localizedDescription)
        }

        // Single-row invariant: keep the oldest, fold the rest.
        if fetched.count > 1 {
            for extra in fetched.dropFirst() {
                context.delete(extra)
            }
            try save(operation: "fold duplicate users", notify: false)
        }
        return fetched.first
    }

    public func replace(with user: User) throws(PersistenceError) {
        if let existing = try currentUser() {
            context.delete(existing)
        }
        context.insert(user)
        try save(operation: "replace user")
    }

    public func update(configure: (User) -> Void) throws(PersistenceError) {
        guard let user = try currentUser() else { throw .notFound }
        configure(user)
        try save(operation: "update user")
    }

    public func deleteUser() throws(PersistenceError) {
        guard let user = try currentUser() else { throw .notFound }
        context.delete(user)
        try save(operation: "delete user")
    }

    // MARK: - Saving

    private func save(operation: String, notify: Bool = true) throws(PersistenceError) {
        do {
            try context.save()
        } catch {
            Log.user.error("Failed to \(operation): \(error.localizedDescription)")
            throw .saveFailed(error.localizedDescription)
        }
        if notify {
            changeCenter?.notify(.userChanged)
        }
    }
}
