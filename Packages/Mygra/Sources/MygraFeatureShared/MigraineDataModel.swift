//
//  MigraineDataModel.swift
//  MygraFeatureShared
//
//  The environment-injected migraine surface every feature shares (successor to the
//  MigraineManager environment object): same verbs, but each goes through a use-case,
//  failures surface as error toasts (never `try?`-swallowed), and the cached list
//  refreshes from the one change stream (including CloudKit imports). Live Activity,
//  widget, watch, Health, Siri, and Spotlight side effects no longer live here — they
//  react to the same stream.
//

import Foundation
import Observation
import MygraCore
import MygraDesignSystem
import os

@MainActor
@Observable
public final class MigraineDataModel {

    // MARK: - Dependencies

    @ObservationIgnored private let loadMigraines: any LoadMigraines
    @ObservationIgnored private let findMigraineUseCase: any FindMigraine
    @ObservationIgnored private let countMigraines: any CountMigraines
    @ObservationIgnored private let logMigraineUseCase: any LogMigraine
    @ObservationIgnored private let startMigraineUseCase: any StartMigraine
    @ObservationIgnored private let updateMigraineUseCase: any UpdateMigraine
    @ObservationIgnored private let endOngoingUseCase: any EndOngoingMigraine
    @ObservationIgnored private let deleteMigraineUseCase: any DeleteMigraine
    @ObservationIgnored private let deleteAllUseCase: any DeleteAllMigraines
    @ObservationIgnored private let recordSampleUseCase: any RecordIntensitySample
    @ObservationIgnored private let removeSampleUseCase: any RemoveIntensitySample
    @ObservationIgnored private let observeChanges: any ObserveMigraineChanges
    @ObservationIgnored private let reviewRequester: (any ReviewRequesting)?
    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private let generateSampleDataUseCase: (any GenerateSampleData)?
    @ObservationIgnored private let toastManager: ToastManager

    // MARK: - State

    /// Every migraine, newest first.
    public private(set) var migraines: [Migraine] = []
    /// The single ongoing migraine (endDate == nil), if any.
    public private(set) var ongoingMigraine: Migraine?
    /// The list filter; `visibleMigraines` recomputes when it changes.
    public var filter = MigraineFilter()
    /// Bumped after every change-stream event so views that compute from the cache re-evaluate.
    public private(set) var changeStamp: Int = 0

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    /// The migraines matching the current filter.
    public var visibleMigraines: [Migraine] {
        migraines.filter { filter.matches($0) }
    }

    // MARK: - Init

    public init(
        loadMigraines: any LoadMigraines,
        findMigraine: any FindMigraine,
        countMigraines: any CountMigraines,
        logMigraine: any LogMigraine,
        startMigraine: any StartMigraine,
        updateMigraine: any UpdateMigraine,
        endOngoing: any EndOngoingMigraine,
        deleteMigraine: any DeleteMigraine,
        deleteAll: any DeleteAllMigraines,
        recordIntensitySample: any RecordIntensitySample,
        removeIntensitySample: any RemoveIntensitySample,
        observeChanges: any ObserveMigraineChanges,
        reviewRequester: (any ReviewRequesting)? = nil,
        defaults: any KeyValueStoring = UserDefaults.standard,
        generateSampleData: (any GenerateSampleData)? = nil,
        toastManager: ToastManager
    ) {
        self.loadMigraines = loadMigraines
        self.findMigraineUseCase = findMigraine
        self.countMigraines = countMigraines
        self.logMigraineUseCase = logMigraine
        self.startMigraineUseCase = startMigraine
        self.updateMigraineUseCase = updateMigraine
        self.endOngoingUseCase = endOngoing
        self.deleteMigraineUseCase = deleteMigraine
        self.deleteAllUseCase = deleteAll
        self.recordSampleUseCase = recordIntensitySample
        self.removeSampleUseCase = removeIntensitySample
        self.observeChanges = observeChanges
        self.reviewRequester = reviewRequester
        self.defaults = defaults
        self.generateSampleDataUseCase = generateSampleData
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
            for await _ in stream {
                guard let self else { return }
                self.refresh()
            }
        }
    }

    // MARK: - Reads

    /// Reloads the cache from the store. Failures toast and leave the last good list.
    public func refresh() {
        do {
            migraines = try loadMigraines()
            ongoingMigraine = migraines.first(where: \.isOngoing)
            changeStamp &+= 1
        } catch {
            Log.migraine.error("Migraine refresh failed: \(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }

    /// The migraine with `id` from the cache, falling back to the store.
    public func migraine(withID id: UUID) -> Migraine? {
        if let cached = migraines.first(where: { $0.id == id }) { return cached }
        do {
            return try findMigraineUseCase(withID: id)
        } catch {
            Log.migraine.error("Migraine lookup failed: \(error.localizedDescription)")
            toastManager.show(error: error)
            return nil
        }
    }

    // MARK: - Writes (failures toast; nothing is silently dropped)

    /// Persists a new migraine and asks for a review on the fifth ever.
    @discardableResult
    public func log(_ migraine: Migraine) -> Bool {
        let logged = surfacing(fallback: false) {
            try logMigraineUseCase(migraine)
            return true
        }
        if logged { maybeRequestReview() }
        return logged
    }

    /// Starts tracking a migraine now; nil when one is already ongoing.
    @discardableResult
    public func start(painLevel: Int, stressLevel: Int, note: String? = nil) -> UUID? {
        surfacing(fallback: nil) { try startMigraineUseCase(painLevel: painLevel, stressLevel: stressLevel, note: note) }
    }

    public func update(_ migraine: Migraine, configure: (Migraine) -> Void) {
        surfacing(fallback: ()) { try updateMigraineUseCase(migraine, configure: configure) }
    }

    public func togglePinned(_ migraine: Migraine) {
        update(migraine) { $0.isPinned.toggle() }
    }

    /// Ends the ongoing migraine. Returns whether one was ended.
    @discardableResult
    public func endOngoing(at endDate: Date = Date()) -> Bool {
        surfacing(fallback: false) { try endOngoingUseCase(at: endDate) }
    }

    public func delete(_ migraine: Migraine) {
        surfacing(fallback: ()) { try deleteMigraineUseCase(migraine) }
    }

    public func deleteAll() {
        surfacing(fallback: ()) { try deleteAllUseCase() }
    }

    public func addIntensitySample(to migraine: Migraine, painLevel: Int, stressLevel: Int, note: String? = nil) {
        surfacing(fallback: ()) { _ = try recordSampleUseCase(for: migraine, painLevel: painLevel, stressLevel: stressLevel, note: note) }
    }

    public func removeIntensitySample(_ sample: IntensitySample, from migraine: Migraine) {
        surfacing(fallback: ()) { try removeSampleUseCase(sample, from: migraine) }
    }

    #if DEBUG
    /// Seeds the demo data set (Settings developer menu).
    public func generateSampleData() {
        guard let generateSampleDataUseCase else { return }
        surfacing(fallback: ()) { try generateSampleDataUseCase() }
    }
    #endif

    // MARK: - Review prompt

    private func maybeRequestReview() {
        guard let reviewRequester else { return }
        let hasPrompted = defaults.bool(forKey: AppStorageKeys.hasPromptedForFifthReview)
        guard let total = try? countMigraines(),
              ReviewMilestone.shouldPrompt(totalMigraines: total, hasPrompted: hasPrompted) else { return }
        defaults.set(true, forKey: AppStorageKeys.hasPromptedForFifthReview)
        reviewRequester.requestReview()
    }

    // MARK: - Error surfacing

    /// Runs a store operation, refreshing the cache on success (the change stream also
    /// refreshes, asynchronously, for writes made elsewhere) and toasting on failure.
    private func surfacing<T>(fallback: T, _ operation: () throws -> T) -> T {
        do {
            let result = try operation()
            refresh()
            return result
        } catch {
            Log.migraine.error("\(error.localizedDescription)")
            toastManager.show(error: error)
            return fallback
        }
    }
}
