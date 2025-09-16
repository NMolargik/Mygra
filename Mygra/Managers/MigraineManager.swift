//
//  MigraineManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import SwiftData
import Observation
import StoreKit
import UIKit
import WidgetKit

enum AppGroup {
    static let id = "group.com.molargiksoftware.mygra"
}

@MainActor
@Observable
final class MigraineManager {

    // MARK: - Notifications
    nonisolated static let migraineCreatedNotification = Notification.Name("MigraineManager.migraineCreated")

    // MARK: - Dependencies
    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private let healthManager: HealthManager?

    // MARK: - Source of truth
    private(set) var migraines: [Migraine] = []

    // Track a single ongoing migraine (endDate == nil)
    private(set) var ongoingMigraine: Migraine? = nil

    var filter: MigraineFilter = MigraineFilter() {
        didSet { Task { await refresh() } }
    }
 
    // Derived, filter-applied list for the UI
    var visibleMigraines: [Migraine] {
        applyFilter(to: migraines)
    }

    // MARK: - Init
    init(context: ModelContext, healthManager: HealthManager? = nil) {
        self.context = context
        self.healthManager = healthManager
        Task { await refresh() }
    }

    // MARK: - Fetch / Refresh
    func refresh() async {
        do {
            var desc = FetchDescriptor<Migraine>(
                // Start with newest first.
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            // Apply “pinned only” at the fetch level when possible for performance.
            if filter.pinnedOnly {
                desc.predicate = #Predicate<Migraine> { $0.pinned == true }
            }
            let fetched = try context.fetch(desc)
            self.migraines = fetched
            // Update the ongoing migraine reference (first ongoing in newest-first list)
            self.ongoingMigraine = fetched.first(where: { $0.isOngoing })

            // Keep the widget up to date with the newest migraine start
            self.updateWidgetSharedState()
        } catch {
            print(MigraineError.fetchFailed(underlying: error).localizedDescription)
            self.migraines = []
            self.ongoingMigraine = nil
        }
    }

    // MARK: - Create
    func create(
        migraine: Migraine,
        reviewScene: UIWindowScene? = nil
    ) {
        context.insert(migraine)

        // If this is an ongoing migraine, track it immediately
        if migraine.isOngoing {
            self.ongoingMigraine = migraine
        }

        // Post creation notification for observers (e.g., InsightManager)
        NotificationCenter.default.post(
            name: MigraineManager.migraineCreatedNotification,
            object: self,
            userInfo: ["migraine": migraine]
        )

        // If completed at creation time, write to HealthKit immediately
        if let hm = healthManager, migraine.endDate != nil {
            Task { await hm.saveHeadacheForMigraine(migraine) }
        }

        saveAndReload()

        // Review prompt on the 5th-ever migraine
        Task { await maybeRequestReviewIfFifthEver(in: reviewScene) }
        
        if migraine.isOngoing {
            MigraineActivityCenter.start(for: migraine.id, startDate: migraine.startDate, severity: migraine.painLevel, notes: migraine.note ?? "")
        }

    }

    // MARK: - Update (mutate in place)
    func update(_ migraine: Migraine, _ mutate: (Migraine) -> Void) {
        let wasOngoing = migraine.isOngoing
        mutate(migraine)
        let isOngoingNow = migraine.isOngoing

        // Keep ongoing tracking in sync:
        if wasOngoing && !isOngoingNow, ongoingMigraine?.id == migraine.id {
            ongoingMigraine = nil
            // End any Live Activity for this migraine
            MigraineActivityCenter.end(for: migraine.id)
        }
        if !wasOngoing && isOngoingNow {
            ongoingMigraine = migraine
            // Start a Live Activity if it became ongoing
            MigraineActivityCenter.start(for: migraine.id, startDate: migraine.startDate, severity: migraine.painLevel, notes: migraine.note ?? "")
        }

        // If this migraine just transitioned to completed, write to HealthKit now
        if wasOngoing && !isOngoingNow, let hm = healthManager {
            Task { await hm.saveHeadacheForMigraine(migraine) }
        }

        saveAndReload()
    }

    func togglePinned(_ migraine: Migraine) {
        migraine.pinned.toggle()
        saveAndReload()
    }

    // MARK: - Delete
    func delete(_ migraine: Migraine) {
        // Clear ongoing if we are deleting the tracked migraine
        if ongoingMigraine?.id == migraine.id {
            ongoingMigraine = nil
        }
        // End any Live Activity
        MigraineActivityCenter.end(for: migraine.id)
        context.delete(migraine)
        saveAndReload()
    }

    func delete(at offsets: IndexSet) {
        for idx in offsets {
            guard idx >= 0 && idx < visibleMigraines.count else { continue }
            let model = visibleMigraines[idx]
            if ongoingMigraine?.id == model.id {
                ongoingMigraine = nil
            }
            MigraineActivityCenter.end(for: model.id)
            context.delete(model)
        }
        saveAndReload()
    }

    // MARK: - Filtering helpers
    private func applyFilter(to items: [Migraine]) -> [Migraine] {
        items.filter { m in
            if let r = filter.dateRange {
                guard r.contains(m.startDate) else { return false }
            }
            if let minPain = filter.minPainLevel {
                guard m.painLevel >= minPain else { return false }
            }
            if !filter.requiredTriggers.isEmpty {
                let set = Set(m.triggers)
                guard !filter.requiredTriggers.subtracting(set).isEmpty == false else { return false }
            }
            if !filter.searchText.isEmpty {
                let t = filter.searchText.lowercased()
                let noteHit = m.note?.lowercased().contains(t) == true
                let insightHit = m.insight?.lowercased().contains(t) == true
                // Also search custom triggers text
                let customHit = m.customTriggers.contains { $0.lowercased().contains(t) }
                guard noteHit || insightHit || customHit else { return false }
            }
            return true
        }
    }

    // MARK: - Widgets sync
    private func updateWidgetSharedState() {
        // Persist the latest migraine start date for the widget, and trigger a reload.
        let defaults = UserDefaults(suiteName: AppGroup.id)
        let latestStart = self.migraines.first?.startDate
        let timestamp = latestStart?.timeIntervalSince1970 ?? 0
        defaults?.set(timestamp, forKey: "lastMigraineStart")
        WidgetCenter.shared.reloadTimelines(ofKind: "DaysSinceLastMigraine")
    }

    // MARK: - Persistence
    private func saveAndReload() {
        do {
            try context.save()
        } catch {
            print(MigraineError.saveFailed(underlying: error).localizedDescription)
        }
        Task { await refresh() }
    }

    // MARK: - Review prompt
    private static let reviewPromptFifthKey = "MigraineManager.hasPromptedForFifthReview"

    // Accept a scene from the caller to remain extension-safe.
    private func maybeRequestReviewIfFifthEver(in scene: UIWindowScene?) async {
        // Avoid prompting more than once for this milestone
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.reviewPromptFifthKey) {
            return
        }

        // Count total migraines in the persistent store (unfiltered)
        do {
            let count = try context.fetchCount(FetchDescriptor<Migraine>())
            guard count == 5 else { return }
        } catch {
            // If counting fails, do not attempt to prompt
            print(MigraineError.fetchFailed(underlying: error).localizedDescription)
            return
        }

        // Mark as prompted to ensure we don't prompt again
        defaults.set(true, forKey: Self.reviewPromptFifthKey)

        // Request review using the provided scene when available.
        if let scene {
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
        } else {
            // No scene available; fall back to the process-wide request on older systems.
            if #available(iOS 18.0, *) {
                // No scene-less API on iOS 18+; silently skip.
            } else {
                SKStoreReviewController.requestReview()
            }
        }
    }
}
