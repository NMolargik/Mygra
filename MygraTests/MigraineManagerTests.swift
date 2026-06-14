//
//  MigraineManagerTests.swift
//  MygraTests
//
//  Behavior tests over a real (isolated, on-disk temp) SwiftData container
//  with fakes for every service seam.
//

import Foundation
import SwiftData
import Testing
@testable import Mygra

@Suite("MigraineManager", .serialized)
@MainActor
struct MigraineManagerTests {

    private func makeManager() throws -> (MigraineManager, FakeKeyValueStore, FakeWidgetReloader, FakeWatchPusher, ModelContainer) {
        let container = try makeTestContainer()
        let defaults = FakeKeyValueStore()
        let widgets = FakeWidgetReloader()
        let watch = FakeWatchPusher()
        let manager = MigraineManager(
            container: container,
            healthManager: nil,
            sharedDefaults: defaults,
            widgetReloader: widgets,
            reviewRequester: FakeReviewRequester(),
            watchPusher: watch
        )
        return (manager, defaults, widgets, watch, container)
    }

    @Test func createInsertsInitialIntensitySample() async throws {
        let (manager, _, _, _, _) = try makeManager()
        let migraine = Migraine(startDate: Date(), painLevel: 7, stressLevel: 4)
        manager.create(migraine: migraine)
        await manager.refresh()

        #expect(manager.migraines.count == 1)
        let samples = try #require(migraine.intensitySamples)
        #expect(samples.count == 1)
        #expect(samples.first?.painLevel == 7)
        #expect(samples.first?.stressLevel == 4)
    }

    @Test func ongoingMigraineIsTracked() async throws {
        let (manager, _, _, _, _) = try makeManager()
        let migraine = Migraine(startDate: Date(), endDate: nil, painLevel: 5, stressLevel: 5)
        manager.create(migraine: migraine)
        await manager.refresh()

        #expect(manager.ongoingMigraine?.id == migraine.id)

        let ended = manager.endOngoingMigraine()
        await manager.refresh()
        #expect(ended)
        #expect(manager.ongoingMigraine == nil)
        #expect(migraine.endDate != nil)
    }

    @Test func endOngoingWithNothingOngoingReturnsFalse() throws {
        let (manager, _, _, _, _) = try makeManager()
        #expect(!manager.endOngoingMigraine())
    }

    @Test func startFromWatchRefusesDuplicates() async throws {
        let (manager, _, _, _, _) = try makeManager()
        let first = manager.startMigraineFromWatch(painLevel: 6, stressLevel: 3)
        await manager.refresh()
        #expect(first != nil)
        #expect(manager.ongoingMigraine != nil)

        let second = manager.startMigraineFromWatch(painLevel: 4, stressLevel: 4)
        #expect(second == nil)
    }

    @Test func refreshWritesSharedStateAndReloadsWidget() async throws {
        let (manager, defaults, widgets, watch, _) = try makeManager()
        let start = Date()
        manager.create(migraine: Migraine(startDate: start, painLevel: 5, stressLevel: 5))
        await manager.refresh()

        let status = defaults.readSharedStatus()
        #expect(status.hasOngoingMigraine)
        #expect(status.lastMigraineStart.map { abs($0.timeIntervalSince(start)) < 1.0 } == true)
        #expect(widgets.reloadedKinds.contains("DaysSinceLastMigraine"))
        #expect(!watch.pushedStatuses.isEmpty)
    }

    @Test func deleteAllClearsStateAndSharedDefaults() async throws {
        let (manager, defaults, _, _, _) = try makeManager()
        manager.create(migraine: Migraine(startDate: Date(), endDate: Date(), painLevel: 5, stressLevel: 5))
        manager.create(migraine: Migraine(startDate: Date().addingTimeInterval(-86_400), endDate: Date(), painLevel: 3, stressLevel: 2))
        await manager.refresh()
        #expect(manager.migraines.count == 2)

        manager.deleteAllMigraines()
        await manager.refresh()
        #expect(manager.migraines.isEmpty)
        #expect(defaults.readSharedStatus().lastMigraineStart == nil)
    }

    @Test func visibleMigrainesApplyFilter() async throws {
        let (manager, _, _, _, _) = try makeManager()
        manager.create(migraine: Migraine(startDate: Date(), endDate: Date(), painLevel: 8, stressLevel: 5))
        manager.create(migraine: Migraine(startDate: Date().addingTimeInterval(-3600), endDate: Date(), painLevel: 2, stressLevel: 1))
        await manager.refresh()

        var filter = MigraineFilter()
        filter.minPainLevel = 5
        manager.filter = filter
        #expect(manager.visibleMigraines.count == 1)
        #expect(manager.visibleMigraines.first?.painLevel == 8)
    }

    @Test func addIntensitySampleUpdatesCurrentLevels() async throws {
        let (manager, _, _, _, _) = try makeManager()
        let migraine = Migraine(startDate: Date(), painLevel: 4, stressLevel: 4)
        manager.create(migraine: migraine)
        await manager.refresh()

        manager.addIntensitySample(to: migraine, pain: 9, stress: 7, note: "worsening")
        #expect(migraine.painLevel == 9)
        #expect(migraine.stressLevel == 7)
        #expect((migraine.intensitySamples ?? []).count == 2)
    }
}
