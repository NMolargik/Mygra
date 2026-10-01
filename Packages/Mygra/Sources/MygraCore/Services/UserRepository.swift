//
//  UserRepository.swift
//  MygraCore
//
//  The single-row user profile boundary. The repository enforces the one-user
//  invariant (CloudKit merges can leave duplicates; extras are folded on read).
//

import Foundation

@MainActor
public protocol UserRepository: AnyObject {
    /// The current profile, or nil before onboarding completes.
    func currentUser() throws(PersistenceError) -> User?

    /// Replaces the profile with `user`.
    func replace(with user: User) throws(PersistenceError)

    /// Applies edits to the current profile.
    func update(configure: (User) -> Void) throws(PersistenceError)

    /// Deletes the profile.
    func deleteUser() throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadUser {
    func callAsFunction() throws(PersistenceError) -> User?
}

public struct LoadUserUseCase: LoadUser {
    private let repository: any UserRepository
    public init(repository: any UserRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> User? {
        try repository.currentUser()
    }
}

@MainActor
public protocol SaveUser {
    func callAsFunction(_ user: User) throws(PersistenceError)
}

public struct SaveUserUseCase: SaveUser {
    private let repository: any UserRepository
    public init(repository: any UserRepository) { self.repository = repository }
    public func callAsFunction(_ user: User) throws(PersistenceError) {
        try repository.replace(with: user)
    }
}

@MainActor
public protocol UpdateUser {
    func callAsFunction(configure: (User) -> Void) throws(PersistenceError)
}

public struct UpdateUserUseCase: UpdateUser {
    private let repository: any UserRepository
    public init(repository: any UserRepository) { self.repository = repository }
    public func callAsFunction(configure: (User) -> Void) throws(PersistenceError) {
        try repository.update(configure: configure)
    }
}

@MainActor
public protocol DeleteUser {
    func callAsFunction() throws(PersistenceError)
}

public struct DeleteUserUseCase: DeleteUser {
    private let repository: any UserRepository
    public init(repository: any UserRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) {
        try repository.deleteUser()
    }
}
