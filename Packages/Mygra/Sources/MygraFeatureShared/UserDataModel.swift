//
//  UserDataModel.swift
//  MygraFeatureShared
//
//  The environment-injected profile surface (successor to UserManager) over use-cases.
//

import Foundation
import Observation
import MygraCore
import MygraDesignSystem
import os

@MainActor
@Observable
public final class UserDataModel {

    @ObservationIgnored private let loadUser: any LoadUser
    @ObservationIgnored private let saveUserUseCase: any SaveUser
    @ObservationIgnored private let updateUserUseCase: any UpdateUser
    @ObservationIgnored private let deleteUserUseCase: any DeleteUser
    @ObservationIgnored private let observeChanges: any ObserveMigraineChanges
    @ObservationIgnored private let toastManager: ToastManager

    /// The current profile, or nil before onboarding completes.
    public private(set) var currentUser: User?

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    public init(
        loadUser: any LoadUser,
        saveUser: any SaveUser,
        updateUser: any UpdateUser,
        deleteUser: any DeleteUser,
        observeChanges: any ObserveMigraineChanges,
        toastManager: ToastManager
    ) {
        self.loadUser = loadUser
        self.saveUserUseCase = saveUser
        self.updateUserUseCase = updateUser
        self.deleteUserUseCase = deleteUser
        self.observeChanges = observeChanges
        self.toastManager = toastManager
        refresh()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let stream = self?.observeChanges() else { return }
            for await change in stream {
                guard let self else { return }
                switch change {
                case .userChanged, .bulk: self.refresh()
                default: break
                }
            }
        }
    }

    public func refresh() {
        do {
            currentUser = try loadUser()
        } catch {
            Log.user.error("User refresh failed: \(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }

    /// Replaces the profile (onboarding).
    public func save(_ user: User) {
        surfacing { try saveUserUseCase(user) }
    }

    /// Applies edits to the current profile.
    public func update(configure: (User) -> Void) {
        surfacing { try updateUserUseCase(configure: configure) }
    }

    /// Copies every field of `edited` onto the stored profile.
    public func apply(_ edited: User) {
        update { $0.apply(edited) }
    }

    public func deleteUser() {
        surfacing { try deleteUserUseCase() }
    }

    /// Runs a store operation, refreshing the profile on success and toasting on failure.
    private func surfacing(_ operation: () throws -> Void) {
        do {
            try operation()
            refresh()
        } catch {
            Log.user.error("\(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }
}
