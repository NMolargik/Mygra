//
//  MigraineStatusSync.swift
//  MygraCore
//
//  Keeps everything outside the app in step with the migraine store: the App Group
//  status (widgets), the watch, and the ongoing-migraine Live Activity. Observes the one
//  change stream and reconciles after every event — the old MigraineManager did this
//  inline in `refresh()`. Pure over seams, so it is host-tested with fakes.
//

import Foundation
import os

@MainActor
public final class MigraineStatusSync {

    private let loadMigraines: any LoadMigraines
    private let observeChanges: any ObserveMigraineChanges
    private let sharedDefaults: (any KeyValueStoring)?
    private let widgets: (any WidgetTimelineReloading)?
    private let watch: (any WatchStatusPushing)?
    private let liveActivity: (any MigraineActivityControlling)?

    /// The migraine whose Live Activity is currently showing.
    public private(set) var ongoingMigraineID: UUID?
    /// The status last written to the App Group.
    public private(set) var lastStatus: SharedMigraineStatus

    private var observationTask: Task<Void, Never>?

    public init(
        loadMigraines: any LoadMigraines,
        observeChanges: any ObserveMigraineChanges,
        sharedDefaults: (any KeyValueStoring)?,
        widgets: (any WidgetTimelineReloading)? = nil,
        watch: (any WatchStatusPushing)? = nil,
        liveActivity: (any MigraineActivityControlling)? = nil
    ) {
        self.loadMigraines = loadMigraines
        self.observeChanges = observeChanges
        self.sharedDefaults = sharedDefaults
        self.widgets = widgets
        self.watch = watch
        self.liveActivity = liveActivity
        self.lastStatus = sharedDefaults?.readSharedStatus() ?? .empty
    }

    deinit {
        observationTask?.cancel()
    }

    /// Reconciles now and keeps reconciling on every change-stream event.
    public func start() {
        syncNow()
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            guard let stream = self?.observeChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                self.syncNow()
            }
        }
    }

    /// The current status as the store sees it (also the watch's status reply).
    public func currentStatus() -> SharedMigraineStatus {
        guard let migraines = try? loadMigraines() else { return lastStatus }
        return SharedMigraineStatus(
            lastMigraineStart: migraines.first?.startDate,
            hasOngoingMigraine: migraines.contains(where: \.isOngoing)
        )
    }

    /// Reconciles the shared status, widgets, watch, and Live Activity with the store.
    public func syncNow() {
        let migraines: [Migraine]
        do {
            migraines = try loadMigraines()
        } catch {
            Log.migraine.error("Status sync fetch failed: \(error.localizedDescription)")
            return
        }

        let ongoing = migraines.first(where: \.isOngoing)
        let current = SharedMigraineStatus(
            lastMigraineStart: migraines.first?.startDate,
            hasOngoingMigraine: ongoing != nil
        )

        reconcileLiveActivity(with: ongoing)

        let previous = lastStatus
        let changedLastStart: Bool = {
            switch (previous.lastMigraineStart, current.lastMigraineStart) {
            case (nil, nil): return false
            case let (old?, new?): return abs(new.timeIntervalSince(old)) > 0.5
            default: return true
            }
        }()
        let changedOngoing = previous.hasOngoingMigraine != current.hasOngoingMigraine

        sharedDefaults?.writeSharedStatus(current)
        lastStatus = current

        if changedLastStart {
            widgets?.reloadTimelines(ofKind: WidgetKind.daysSinceLastMigraine)
        }
        if changedLastStart || changedOngoing {
            watch?.pushStatus(current)
        }
    }

    private func reconcileLiveActivity(with ongoing: Migraine?) {
        guard let liveActivity else {
            ongoingMigraineID = ongoing?.id
            return
        }
        let currentID = ongoing?.id
        if ongoingMigraineID != currentID {
            if let previous = ongoingMigraineID {
                liveActivity.end(for: previous)
            }
            if let ongoing {
                liveActivity.ensureStarted(
                    for: ongoing.id,
                    startDate: ongoing.startDate,
                    painLevel: ongoing.painLevel,
                    stressLevel: ongoing.stressLevel,
                    note: ongoing.note ?? ""
                )
            }
            ongoingMigraineID = currentID
        } else if let ongoing {
            liveActivity.update(for: ongoing.id, painLevel: ongoing.painLevel, stressLevel: ongoing.stressLevel, note: ongoing.note ?? "")
        }
    }
}
