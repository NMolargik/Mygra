//
//  AppSeams.swift
//  Mygra
//
//  Production conformances for the Core seams whose framework types can't live in the
//  package: Spotlight indexing (AppEntity), intent donation (AppIntents), and the App
//  Store review prompt (needs the window scene).
//

import AppIntents
import CoreSpotlight
import Foundation
import StoreKit
import UIKit
import MygraCore
import os

/// Indexes migraines into Spotlight so the system can semantically search them.
struct SpotlightIndexer: MigraineIndexing {
    nonisolated init() {}

    /// Re-indexes every migraine. Safe to call repeatedly; CoreSpotlight dedupes by identifier.
    func reindex(migraines: [Migraine]) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let entities = migraines.map(MigraineEntity.init)
        guard !entities.isEmpty else { return }

        Task.detached(priority: .utility) {
            do {
                try await CSSearchableIndex.default().indexAppEntities(entities)
                Log.spotlight.info("Indexed \(entities.count) migraines into Spotlight")
            } catch {
                Log.spotlight.error("Spotlight indexing failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Donates intents so Siri can suggest them from the user's behavior.
struct IntentDonor: IntentDonating {
    nonisolated init() {}

    func donate(_ action: DonatableAction) {
        Task {
            do {
                switch action {
                case .startMigraine: _ = try await StartMigraineIntent().donate()
                case .endMigraine: _ = try await EndMigraineIntent().donate()
                }
            } catch {
                Log.migraine.error("Intent donation failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Requests a review in the foreground window scene.
struct AppStoreReviewRequester: ReviewRequesting {
    nonisolated init() {}

    func requestReview() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let scene else { return }
        AppStore.requestReview(in: scene)
    }
}
