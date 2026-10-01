//
//  TestSupport.swift
//  MygraCoreTests
//
//  Fakes for every Core seam.
//

import Foundation
import MygraCore

final class FakeKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private(set) var storage: [String: Any] = [:]

    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

@MainActor
final class FakeWidgetReloader: WidgetTimelineReloading {
    private(set) var reloadedKinds: [String] = []
    func reloadTimelines(ofKind kind: String) { reloadedKinds.append(kind) }
}

@MainActor
final class FakeWatchPusher: WatchStatusPushing {
    private(set) var pushedStatuses: [SharedMigraineStatus] = []
    func pushStatus(_ status: SharedMigraineStatus) { pushedStatuses.append(status) }
}

@MainActor
final class FakeLiveActivity: MigraineActivityControlling {
    enum Event: Equatable { case started(UUID), updated(UUID, Int, Int), ended(UUID) }
    private(set) var events: [Event] = []
    func ensureStarted(for migraineID: UUID, startDate: Date, painLevel: Int, stressLevel: Int, note: String) {
        events.append(.started(migraineID))
    }
    func update(for migraineID: UUID, painLevel: Int, stressLevel: Int, note: String) {
        events.append(.updated(migraineID, painLevel, stressLevel))
    }
    func end(for migraineID: UUID) { events.append(.ended(migraineID)) }
}

@MainActor
final class FakeHeadacheRecorder: HeadacheRecording {
    private(set) var recorded: [(start: Date, end: Date, severity: Severity)] = []
    func recordHeadache(start: Date, end: Date, severity: Severity) async throws {
        recorded.append((start, end, severity))
    }
}

@MainActor
final class FakeIntentDonor: IntentDonating {
    private(set) var donated: [DonatableAction] = []
    func donate(_ action: DonatableAction) { donated.append(action) }
}

/// An in-memory `MigraineRepository` so use-cases are tested without SwiftData.
@MainActor
final class InMemoryMigraineRepository: MigraineRepository {
    var storage: [Migraine] = []
    var errorToThrow: PersistenceError?
    let changeCenter = MigraineChangeCenter()

    private func check() throws(PersistenceError) {
        if let errorToThrow { throw errorToThrow }
    }

    func migraines() throws(PersistenceError) -> [Migraine] {
        try check()
        return storage.sorted { $0.startDate > $1.startDate }
    }
    func migraine(withID id: UUID) throws(PersistenceError) -> Migraine? {
        try check()
        return storage.first { $0.id == id }
    }
    func count() throws(PersistenceError) -> Int {
        try check()
        return storage.count
    }
    func insert(_ migraine: Migraine) throws(PersistenceError) {
        try check()
        storage.append(migraine)
        changeCenter.notify(.migraineLogged(migraine.id))
    }
    func update(_ migraine: Migraine, configure: (Migraine) -> Void) throws(PersistenceError) {
        try check()
        configure(migraine)
        changeCenter.notify(.migraineUpdated(migraine.id))
    }
    func delete(_ migraine: Migraine) throws(PersistenceError) {
        try check()
        storage.removeAll { $0.id == migraine.id }
        changeCenter.notify(.migraineDeleted(migraine.id))
    }
    func deleteAll() throws(PersistenceError) {
        try check()
        storage.removeAll()
        changeCenter.notify(.bulk)
    }
    @discardableResult
    func addIntensitySample(to migraine: Migraine, timestamp: Date, painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> IntensitySample {
        try check()
        let sample = IntensitySample(timestamp: timestamp, painLevel: painLevel, stressLevel: stressLevel, note: note, parentMigraine: migraine)
        migraine.painLevel = painLevel
        migraine.stressLevel = stressLevel
        changeCenter.notify(.migraineUpdated(migraine.id))
        return sample
    }
    func removeIntensitySample(_ sample: IntensitySample, from migraine: Migraine) throws(PersistenceError) {
        try check()
        changeCenter.notify(.migraineUpdated(migraine.id))
    }
}

@MainActor
func makeMigraine(
    start: Date = Date(),
    end: Date? = nil,
    pain: Int = 5,
    stress: Int = 5,
    note: String? = nil,
    triggers: [MigraineTrigger] = [],
    customTriggers: [String] = [],
    foods: [String] = []
) -> Migraine {
    Migraine(startDate: start, endDate: end, painLevel: pain, stressLevel: stress, note: note, triggers: triggers, customTriggers: customTriggers, foodsEaten: foods)
}
