//
//  MigraineStatusSyncTests.swift
//  MygraCoreTests
//
//  The cross-process reconciler: shared defaults, widget reloads, watch pushes, and
//  Live Activity lifecycle over fake seams.
//

import Foundation
import Testing
import MygraCore

@Suite("MigraineStatusSync")
@MainActor
struct MigraineStatusSyncTests {

    private struct Harness {
        let repository = InMemoryMigraineRepository()
        let defaults = FakeKeyValueStore()
        let widgets = FakeWidgetReloader()
        let watch = FakeWatchPusher()
        let activity = FakeLiveActivity()
        let sync: MigraineStatusSync

        init() {
            sync = MigraineStatusSync(
                loadMigraines: LoadMigrainesUseCase(repository: repository),
                observeChanges: ObserveMigraineChangesUseCase(center: repository.changeCenter),
                sharedDefaults: defaults,
                widgets: widgets,
                watch: watch,
                liveActivity: activity
            )
        }
    }

    @Test func syncWritesSharedStatusAndReloadsWidgetOnNewStart() {
        let h = Harness()
        let start = Date()
        h.repository.storage = [makeMigraine(start: start)]

        h.sync.syncNow()

        let status = h.defaults.readSharedStatus()
        #expect(status.hasOngoingMigraine)
        #expect(status.lastMigraineStart.map { abs($0.timeIntervalSince(start)) < 1 } == true)
        #expect(h.widgets.reloadedKinds == [WidgetKind.daysSinceLastMigraine])
        #expect(h.watch.pushedStatuses.count == 1)
        #expect(h.activity.events.first == .started(h.repository.storage[0].id))
    }

    @Test func unchangedStatusDoesNotRepush() {
        let h = Harness()
        h.repository.storage = [makeMigraine(start: Date(), end: Date())]
        h.sync.syncNow()
        h.sync.syncNow()
        #expect(h.widgets.reloadedKinds.count == 1)
        #expect(h.watch.pushedStatuses.count == 1)
        #expect(h.activity.events.isEmpty)
    }

    @Test func endingMigraineEndsActivityAndPushesWatch() {
        let h = Harness()
        let migraine = makeMigraine(start: Date())
        h.repository.storage = [migraine]
        h.sync.syncNow()

        migraine.endDate = Date()
        h.sync.syncNow()

        #expect(h.activity.events.last == .ended(migraine.id))
        #expect(h.watch.pushedStatuses.count == 2)
        #expect(h.defaults.readSharedStatus().hasOngoingMigraine == false)
        // Widget only reloads when the last start changes.
        #expect(h.widgets.reloadedKinds.count == 1)
    }

    @Test func levelChangesUpdateTheActivity() {
        let h = Harness()
        let migraine = makeMigraine(start: Date(), pain: 4, stress: 4)
        h.repository.storage = [migraine]
        h.sync.syncNow()
        migraine.painLevel = 9
        h.sync.syncNow()
        #expect(h.activity.events.last == .updated(migraine.id, 9, 4))
    }

    @Test func deletingEverythingResetsSharedStatus() {
        let h = Harness()
        h.repository.storage = [makeMigraine(start: Date(), end: Date())]
        h.sync.syncNow()
        h.repository.storage = []
        h.sync.syncNow()
        #expect(h.defaults.readSharedStatus().lastMigraineStart == nil)
        #expect(h.watch.pushedStatuses.last == .empty)
    }

    @Test func startObservesTheChangeStream() async {
        let h = Harness()
        h.sync.start()
        let migraine = makeMigraine(start: Date())
        for _ in 0..<100 where h.defaults.readSharedStatus().hasOngoingMigraine == false {
            try? h.repository.insert(migraine)
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(h.defaults.readSharedStatus().hasOngoingMigraine)
    }
}
