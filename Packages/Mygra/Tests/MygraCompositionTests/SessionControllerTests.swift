//
//  SessionControllerTests.swift
//  MygraCompositionTests
//
//  Composition-root behavior: graph wiring, deep-link staging, the App Intent hand-off,
//  and Spotlight reindex observation — over a real (on-disk, CloudKit-free) container
//  and fake seams.
//

import Foundation
import Testing
import MygraCore
import MygraData
@testable import MygraComposition

private final class FakeKeyValueStore: KeyValueStoring, @unchecked Sendable {
    var storage: [String: Any] = [:]
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

@MainActor
private final class FakeIndexer: MigraineIndexing {
    private(set) var reindexCalls: [[Migraine]] = []
    func reindex(migraines: [Migraine]) { reindexCalls.append(migraines) }
}

@MainActor
private final class FakeWidgetReloader: WidgetTimelineReloading {
    private(set) var kinds: [String] = []
    func reloadTimelines(ofKind kind: String) { kinds.append(kind) }
}

@Suite("SessionController", .serialized)
@MainActor
struct SessionControllerTests {

    private func makeSession(indexer: FakeIndexer? = nil, sharedDefaults: FakeKeyValueStore = FakeKeyValueStore(), widgets: FakeWidgetReloader = FakeWidgetReloader()) throws -> SessionController {
        SessionController(
            container: try MygraStore.makeTemporaryContainer(),
            defaults: FakeKeyValueStore(),
            sharedDefaults: sharedDefaults,
            indexer: indexer,
            widgetReloader: widgets,
            indexDebounce: .milliseconds(20)
        )
    }

    @Test("the graph shares one store: logging through the model is visible to use-cases")
    func graphWiring() async throws {
        let session = try makeSession()
        #expect(try session.loadMigraines().isEmpty)

        let migraine = Migraine(startDate: Date(), painLevel: 5, stressLevel: 5)
        #expect(session.migraineData.log(migraine))

        #expect(try session.loadMigraines().count == 1)
        #expect(try session.findMigraine(withID: migraine.id)?.id == migraine.id)
        #expect(session.migraineData.ongoingMigraine?.id == migraine.id)
        #expect(try session.endOngoingMigraine())
        // Writes made through use-cases (intents, watch) reach the model via the change stream.
        for _ in 0..<100 where session.migraineData.ongoingMigraine != nil {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(session.migraineData.ongoingMigraine == nil)
    }

    @Test("URLs stage a pending deep link; unknown URLs are ignored")
    func deepLinks() throws {
        let session = try makeSession()
        session.handle(url: URL(string: "mygra://calendar")!)
        #expect(session.pendingDeepLink == .calendar)
        session.pendingDeepLink = nil
        session.handle(url: URL(string: "https://example.com")!)
        #expect(session.pendingDeepLink == nil)
    }

    @Test("an App Intent hand-off is consumed on start")
    func intentHandoff() throws {
        let shared = FakeKeyValueStore()
        DeepLink.settings.storePending(in: shared)
        let session = try makeSession(sharedDefaults: shared)
        session.start()
        #expect(session.pendingDeepLink == .settings)
        #expect(DeepLink.takePending(from: shared) == nil)
    }

    @Test("start seeds Spotlight and syncs the shared status")
    func startSeedsIndexAndStatus() throws {
        let indexer = FakeIndexer()
        let shared = FakeKeyValueStore()
        let widgets = FakeWidgetReloader()
        let session = try makeSession(indexer: indexer, sharedDefaults: shared, widgets: widgets)
        session.migraineData.log(Migraine(startDate: Date(), endDate: Date(), painLevel: 3, stressLevel: 3))

        session.start()

        #expect(indexer.reindexCalls.last?.count == 1)
        #expect(shared.readSharedStatus().lastMigraineStart != nil)
        #expect(widgets.kinds.contains(WidgetKind.daysSinceLastMigraine))
    }

    @Test("change-stream events reindex once per burst and skip unchanged data")
    func reindexObservation() async throws {
        let indexer = FakeIndexer()
        let session = try makeSession(indexer: indexer)
        session.reindexMigraines()
        let baseline = indexer.reindexCalls.count

        session.migraineData.log(Migraine(startDate: Date(), painLevel: 5, stressLevel: 5, note: "a"))
        session.migraineData.log(Migraine(startDate: Date(), painLevel: 5, stressLevel: 5, note: "b"))
        for _ in 0..<100 where indexer.reindexCalls.count == baseline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(indexer.reindexCalls.count == baseline + 1)
        #expect(indexer.reindexCalls.last?.count == 2)

        // Nothing indexed changed → no rebuild.
        session.reindexMigrainesIfNeeded()
        #expect(indexer.reindexCalls.count == baseline + 1)
    }
}
