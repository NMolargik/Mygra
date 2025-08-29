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

    // Active filters (tweak as you like)
    struct Filter: Equatable {
        var pinnedOnly: Bool = false
        var dateRange: ClosedRange<Date>? = nil
        var minPainLevel: Int? = nil
        var requiredTriggers: Set<MigraineTrigger> = []
        var searchText: String = "" // searches note/insight
    }

    var filter: Filter = Filter() {
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
        } catch {
            // In production you may want to surface this via a published error state.
            print("MigraineManager.refresh() fetch error: \(error)")
            self.migraines = []
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
        saveAndReload()
        return model
    }

    // MARK: - Update (mutate in place)
    func update(_ migraine: Migraine, _ mutate: (Migraine) -> Void) {
        mutate(migraine)
        saveAndReload()
    }

    func togglePinned(_ migraine: Migraine) {
        migraine.pinned.toggle()
        saveAndReload()
    }

    // MARK: - Delete
    func delete(_ migraine: Migraine) {
        context.delete(migraine)
        saveAndReload()
    }

    func delete(at offsets: IndexSet) {
        for idx in offsets {
            guard idx >= 0 && idx < visibleMigraines.count else { continue }
            let model = visibleMigraines[idx]
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
