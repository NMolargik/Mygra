//
//  MigraineManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class MigraineManager {

    // MARK: - Dependencies
    @ObservationIgnored
    private let context: ModelContext

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
    init(context: ModelContext) {
        self.context = context
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
        } catch {
            // In production you may want to surface this via a published error state.
            print("MigraineManager.refresh() fetch error: \(error)")
            self.migraines = []
            self.ongoingMigraine = nil
        }
    }

    // MARK: - Create
    @discardableResult
    func create(
        startDate: Date,
        endDate: Date? = nil,
        painLevel: Int,
        stressLevel: Int,
        pinned: Bool = false,
        note: String? = nil,
        insight: String? = nil,
        triggers: [MigraineTrigger] = [],
        foodsEaten: [String] = [],
        weather: WeatherData? = nil,
        health: HealthData? = nil
    ) -> Migraine {
        let model = Migraine(
            pinned: pinned,
            startDate: startDate,
            endDate: endDate,
            painLevel: painLevel,
            stressLevel: stressLevel,
            note: note,
            insight: insight,
            triggers: triggers,
            foodsEaten: foodsEaten,
            weather: weather,
            health: health
        )
        context.insert(model)

        // If this is an ongoing migraine, track it immediately
        if model.isOngoing {
            self.ongoingMigraine = model
        }

        saveAndReload()
        return model
    }

    // MARK: - Update (mutate in place)
    func update(_ migraine: Migraine, _ mutate: (Migraine) -> Void) {
        let wasOngoing = migraine.isOngoing
        mutate(migraine)
        let isOngoingNow = migraine.isOngoing

        // Keep ongoing tracking in sync:
        // - If it was ongoing and is no longer, clear if it was the tracked one.
        if wasOngoing && !isOngoingNow, ongoingMigraine?.id == migraine.id {
            ongoingMigraine = nil
        }
        // - If it becomes ongoing, set it.
        if !wasOngoing && isOngoingNow {
            ongoingMigraine = migraine
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
                guard noteHit || insightHit else { return false }
            }
            return true
        }
    }

    // MARK: - Persistence
    private func saveAndReload() {
        do {
            try context.save()
        } catch {
            print("MigraineManager.save error: \(error)")
        }
        // Re-fetch so the in-memory list stays sorted and consistent.
        Task { await refresh() }
    }
}
