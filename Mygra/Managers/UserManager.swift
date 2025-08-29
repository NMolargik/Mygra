//
//  UserManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class UserManager {

    // MARK: - Dependencies
    @ObservationIgnored
    let context: ModelContext

    // MARK: - Source of truth
    private(set) var currentUser: User?
    
    var isRefreshing: Bool = false

    // MARK: - Init
    init(context: ModelContext) {
        self.context = context
        Task {
            await refresh()
            print("User at start: \(currentUser.debugDescription)")
        }
        
    }

    // MARK: - Refresh
    func refresh() async {
        do {
            self.isRefreshing = true
            let desc = FetchDescriptor<User>()
            let fetched = try context.fetch(desc)
            // Enforce singleton invariant: pick the first if any exist.
            self.currentUser = fetched.first
            self.isRefreshing = false
        } catch {
            print("UserManager.refresh error: \(error)")
            self.currentUser = nil
            self.isRefreshing = false
        }
    }

    // MARK: - Create or Replace
    func createOrReplace(
        newUser: User
    ) {
        // Delete any existing user
        if let u = currentUser {
            context.delete(u)
        }
        context.insert(newUser)
        saveAndReload()
        print("User Saved!")
    }

    // MARK: - Update
    func update(_ mutate: (User) -> Void) {
        guard let u = currentUser else { return }
        mutate(u)
        saveAndReload()
    }

    // MARK: - Delete
    func deleteUser() {
        guard let u = currentUser else { return }
        context.delete(u)
        saveAndReload()
    }

    // MARK: - Persistence
    private func saveAndReload() {
        do {
            try context.save()
        } catch {
            print("UserManager.save error: \(error)")
        }
        Task { await refresh() }
    }
}
