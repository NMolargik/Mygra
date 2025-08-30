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
    var isRestoringFromCloud: Bool = false

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
            // Optional safety: if more than one slipped in via sync/merge, keep the first and delete extras.
            if fetched.count > 1 {
                for extra in fetched.dropFirst() {
                    context.delete(extra)
                }
                try? context.save()
            }
            self.isRefreshing = false
        } catch {
            print("UserManager.refresh error: \(error)")
            self.currentUser = nil
            self.isRefreshing = false
        }
    }

    // MARK: - Restore from iCloud
    /// Attempts to discover/download the User from the CloudKit-backed store.
    /// CloudKit sync is asynchronous; we poll for a short window to allow sync to complete.
    func restoreFromCloud(timeout: TimeInterval = 3, pollInterval: TimeInterval = 1.0) async {
        guard currentUser == nil else { return }
        isRestoringFromCloud = true
        defer { isRestoringFromCloud = false }

        // Immediate refresh attempt
        await refresh()
        if currentUser != nil { return }

        // Poll with a timeout to allow CloudKit to bring down records
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, currentUser == nil {
            // Sleep for the poll interval
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000))
            // Try another refresh
            await refresh()
            if currentUser != nil { break }
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
