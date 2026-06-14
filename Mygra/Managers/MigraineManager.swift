//
//  MigraineManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import SwiftData
import Observation
import UIKit
import AppIntents
import CoreSpotlight
import os

@MainActor
@Observable
final class MigraineManager {

    // MARK: - Notifications
    nonisolated static let migraineCreatedNotification = Notification.Name("MigraineManager.migraineCreated")

    // MARK: - Dependencies
    // The container is retained alongside the context: a ModelContext does
    // not retain its container, and a deallocated container traps on fetch.
    @ObservationIgnored
    private let container: ModelContainer
    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private let healthManager: HealthManager?
    @ObservationIgnored
    private let sharedDefaults: KeyValueStoring?
    @ObservationIgnored
    private let widgetReloader: WidgetTimelineReloading
    @ObservationIgnored
    private let reviewRequester: ReviewRequesting
    @ObservationIgnored
    private weak var watchPusher: WatchStatusPushing?

    // MARK: - Source of truth
    private(set) var migraines: [Migraine] = []

    // Track a single ongoing migraine (endDate == nil)
    private(set) var ongoingMigraine: Migraine? = nil

    var filter: MigraineFilter = MigraineFilter() {
        didSet { Task { await refresh() } }
    }

    // Derived, filter-applied list for the UI
    var visibleMigraines: [Migraine] {
        migraines.filter { filter.matches($0) }
    }

    // MARK: - Init
    init(
        container: ModelContainer,
        healthManager: HealthManager? = nil,
        sharedDefaults: KeyValueStoring? = UserDefaults(suiteName: AppGroup.id),
        widgetReloader: WidgetTimelineReloading = WidgetCenterReloader(),
        reviewRequester: ReviewRequesting = AppStoreReviewRequester(),
        watchPusher: WatchStatusPushing? = nil
    ) {
        self.container = container
        self.context = container.mainContext
        self.healthManager = healthManager
        self.sharedDefaults = sharedDefaults
        self.widgetReloader = widgetReloader
        self.reviewRequester = reviewRequester
        self.watchPusher = watchPusher
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
            let previousOngoingID = self.ongoingMigraine?.id
            let newOngoing = fetched.first(where: { $0.isOngoing })
            self.ongoingMigraine = newOngoing

            // Centralize Live Activity lifecycle: end previous if changed, start new if needed
            let currentID = newOngoing?.id
            if previousOngoingID != currentID {
                if let prev = previousOngoingID {
                    MigraineActivityCenter.end(for: prev)
                }
                if let og = newOngoing {
                    MigraineActivityCenter.ensureStarted(for: og.id, startDate: og.startDate, severity: og.painLevel, stressLevel: og.stressLevel, notes: og.note ?? "")
                }
            }

            // Keep the widget up to date with the newest migraine start
            self.updateWidgetSharedState()

            // Refresh Spotlight's semantic index of migraines.
            self.indexForSpotlight()
        } catch {
            Log.migraine.error("Fetch failed: \(error)")
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

        // Create the initial intensity sample from the migraine's starting pain/stress levels
        let initialSample = IntensitySample(
            timestamp: migraine.startDate,
            painLevel: migraine.painLevel,
            stressLevel: migraine.stressLevel,
            note: nil,
            parentMigraine: migraine
        )
        context.insert(initialSample)
        if migraine.intensitySamples == nil {
            migraine.intensitySamples = []
        }
        migraine.intensitySamples?.append(initialSample)

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

        // Donate to Siri so it can predict this action (ongoing migraines only).
        if migraine.isOngoing {
            donateIntent(StartMigraineIntent())
        }

        // Review prompt on the 5th-ever migraine
        Task { await maybeRequestReviewIfFifthEver(in: reviewScene) }
    }

    // MARK: - Update (mutate in place)
    func update(_ migraine: Migraine, _ mutate: (Migraine) -> Void) {
        let wasOngoing = migraine.isOngoing
        mutate(migraine)
        let isOngoingNow = migraine.isOngoing

        // If this migraine just transitioned to completed, end any Live Activity and write to HealthKit
        if wasOngoing && !isOngoingNow {
            MigraineActivityCenter.end(for: migraine.id)
            if let hm = healthManager {
                Task { await hm.saveHeadacheForMigraine(migraine) }
            }
        }

        saveAndReload()
    }

    func togglePinned(_ migraine: Migraine) {
        migraine.isPinned.toggle()
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

    /// Deletes all migraines from the store, ends any associated Live Activities,
    /// clears the ongoing reference, and saves.
    /// Intended for use by full data-deletion flows.
    func deleteAllMigraines() {
        for m in migraines {
            MigraineActivityCenter.end(for: m.id)
            context.delete(m)
        }
        ongoingMigraine = nil
        saveAndReload()
    }

    // MARK: - Intensity Samples

    /// Adds an intensity sample to a migraine and updates the Live Activity.
    func addIntensitySample(
        to migraine: Migraine,
        pain: Int,
        stress: Int,
        note: String? = nil
    ) {
        let sample = IntensitySample(
            timestamp: Date(),
            painLevel: pain,
            stressLevel: stress,
            note: note,
            parentMigraine: migraine
        )
        context.insert(sample)
        if migraine.intensitySamples == nil {
            migraine.intensitySamples = []
        }
        migraine.intensitySamples?.append(sample)

        // Update the migraine's current pain/stress levels to the latest
        migraine.painLevel = pain
        migraine.stressLevel = stress

        // Update Live Activity if ongoing
        if migraine.isOngoing {
            MigraineActivityCenter.update(
                for: migraine.id,
                severity: pain,
                stressLevel: stress,
                notes: migraine.note ?? ""
            )
        }

        saveAndReload()
    }

    /// Removes an intensity sample from a migraine.
    func removeIntensitySample(_ sample: IntensitySample, from migraine: Migraine) {
        migraine.intensitySamples?.removeAll { $0.id == sample.id }
        context.delete(sample)
        saveAndReload()
    }

    /// Every migraine in the store, newest first, ignoring the active filter.
    /// Used by export and other whole-dataset flows.
    func allMigraines() throws -> [Migraine] {
        try context.fetch(
            FetchDescriptor<Migraine>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        )
    }

    // MARK: - Watch commands

    /// Ends the ongoing migraine (e.g., from the watch). Returns whether one was ended.
    @discardableResult
    func endOngoingMigraine() -> Bool {
        guard let migraine = ongoingMigraine else { return false }
        update(migraine) { $0.endDate = Date() }
        donateIntent(EndMigraineIntent())
        return true
    }

    /// Starts a migraine programmatically (watch, Siri, Shortcuts, automations).
    /// Returns the new ID, or nil when one is already ongoing.
    @discardableResult
    func startMigraine(painLevel: Int, stressLevel: Int, note: String? = nil) -> UUID? {
        guard ongoingMigraine == nil else { return nil }
        let migraine = Migraine(
            startDate: Date(),
            endDate: nil,
            painLevel: painLevel,
            stressLevel: stressLevel,
            note: note,
            triggers: [],
            customTriggers: [],
            foodsEaten: []
        )
        create(migraine: migraine, reviewScene: nil)
        return migraine.id
    }

    /// Starts a migraine from a watch command, tagged with its source.
    func startMigraineFromWatch(painLevel: Int, stressLevel: Int) -> UUID? {
        startMigraine(painLevel: painLevel, stressLevel: stressLevel, note: String(localized: "Started from Apple Watch"))
    }

    // MARK: - Widgets sync
    private func updateWidgetSharedState() {
        // Persist the latest migraine start date for the widget, and trigger pushes when either
        // the latest start OR the ongoing state changes. Also handle the empty state by pushing a reset.
        let previous = sharedDefaults?.readSharedStatus()
            ?? SharedMigraineStatus(lastMigraineStart: nil, hasOngoingMigraine: false)

        let current = SharedMigraineStatus(
            lastMigraineStart: migraines.first?.startDate,
            hasOngoingMigraine: ongoingMigraine != nil
        )

        let changedLastStart: Bool = {
            switch (previous.lastMigraineStart, current.lastMigraineStart) {
            case (nil, nil): return false
            case let (old?, new?): return abs(new.timeIntervalSince(old)) > 0.5
            default: return true
            }
        }()
        let changedHasOngoing = previous.hasOngoingMigraine != current.hasOngoingMigraine

        sharedDefaults?.writeSharedStatus(current)

        if changedLastStart {
            widgetReloader.reloadTimelines(ofKind: "DaysSinceLastMigraine")
        }
        if changedLastStart || changedHasOngoing {
            watchPusher?.pushStatus(current)
        }
    }

    // MARK: - App Intents donation & Spotlight indexing

    /// Donates an intent so Siri can suggest it from the user's behavior.
    private func donateIntent(_ intent: some AppIntent) {
        guard !MygraApp.isRunningTests else { return }
        Task {
            do { _ = try await intent.donate() }
            catch { Log.migraine.error("Intent donation failed: \(error)") }
        }
    }

    /// Re-indexes all migraines for Spotlight semantic search.
    private func indexForSpotlight() {
        guard !MygraApp.isRunningTests else { return }
        let entities = migraines.map(MigraineEntity.init)
        Task {
            do { try await CSSearchableIndex.default().indexAppEntities(entities) }
            catch { Log.migraine.error("Spotlight indexing failed: \(error)") }
        }
    }

    // MARK: - Persistence
    private func saveAndReload() {
        do {
            try context.save()
        } catch {
            Log.migraine.error("Save failed: \(error)")
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
            Log.migraine.error("Review-count fetch failed: \(error)")
            return
        }

        // Mark as prompted to ensure we don't prompt again
        defaults.set(true, forKey: Self.reviewPromptFifthKey)

        // Request review using the provided scene when available.
        guard let scene else { return }
        reviewRequester.requestReview(in: scene)
    }
}
