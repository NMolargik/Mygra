//
//  RepositoryTests.swift
//  MygraDataTests
//
//  Behavior tests for the SwiftData-backed repositories. Serialized because each test
//  owns a SwiftData container; each gets a unique on-disk temp store — parallel
//  in-memory containers share a /dev/null SQLite identity and crash the host under load.
//

import Foundation
import SwiftData
import Testing
import MygraCore
@testable import MygraData

@Suite("Repositories", .serialized)
@MainActor
struct RepositoryTests {

    private struct Harness {
        let container: ModelContainer
        let changeCenter = MigraineChangeCenter()
        let migraines: DefaultMigraineRepository
        let tags: DefaultTagRepository
        let users: DefaultUserRepository

        init() throws {
            container = try MygraStore.makeTemporaryContainer()
            migraines = DefaultMigraineRepository(container: container, changeCenter: changeCenter)
            tags = DefaultTagRepository(container: container, changeCenter: changeCenter)
            users = DefaultUserRepository(container: container, changeCenter: changeCenter)
        }
    }

    // MARK: - Migraines

    @Test("insert seeds the initial intensity sample and sorts newest first")
    func insertSeedsSample() throws {
        let h = try Harness()
        let older = Migraine(startDate: Date().addingTimeInterval(-86_400), endDate: Date(), painLevel: 7, stressLevel: 4)
        let newer = Migraine(startDate: Date(), painLevel: 3, stressLevel: 2)
        try h.migraines.insert(older)
        try h.migraines.insert(newer)

        let all = try h.migraines.migraines()
        #expect(all.map(\.id) == [newer.id, older.id])
        #expect(try h.migraines.count() == 2)
        let samples = try #require(older.intensitySamples)
        #expect(samples.count == 1)
        #expect(samples.first?.painLevel == 7)
        #expect(try h.migraines.migraine(withID: older.id)?.id == older.id)
        #expect(try h.migraines.migraine(withID: UUID()) == nil)
    }

    @Test("update persists edits; delete removes; deleteAll clears")
    func updateDeleteAll() throws {
        let h = try Harness()
        let migraine = Migraine(startDate: Date(), painLevel: 5, stressLevel: 5)
        try h.migraines.insert(migraine)

        try h.migraines.update(migraine) { $0.endDate = Date() }
        #expect(try h.migraines.migraines().first?.isOngoing == false)

        try h.migraines.insert(Migraine(startDate: Date(), painLevel: 1, stressLevel: 1))
        try h.migraines.delete(migraine)
        #expect(try h.migraines.count() == 1)

        try h.migraines.deleteAll()
        #expect(try h.migraines.count() == 0)
    }

    @Test("intensity samples update the headline levels and can be removed")
    func intensitySamples() throws {
        let h = try Harness()
        let migraine = Migraine(startDate: Date(), painLevel: 4, stressLevel: 4)
        try h.migraines.insert(migraine)

        let sample = try h.migraines.addIntensitySample(to: migraine, timestamp: Date(), painLevel: 9, stressLevel: 7, note: "worsening")
        #expect(migraine.painLevel == 9)
        #expect(migraine.stressLevel == 7)
        #expect((migraine.intensitySamples ?? []).count == 2)

        try h.migraines.removeIntensitySample(sample, from: migraine)
        #expect((migraine.intensitySamples ?? []).count == 1)
    }

    @Test("mutations notify the change stream with payloads")
    func mutationsNotify() async throws {
        let h = try Harness()
        var iterator = h.changeCenter.changes().makeAsyncIterator()
        let migraine = Migraine(startDate: Date(), painLevel: 5, stressLevel: 5)
        try h.migraines.insert(migraine)
        let event = await iterator.next()
        #expect(event == .migraineLogged(migraine.id))
    }

    // MARK: - Tags

    @Test("create assigns increasing sort indexes; move renumbers")
    func tagOrdering() throws {
        let h = try Harness()
        try h.tags.create(name: "A", colorHex: "#111111")
        try h.tags.create(name: "B", colorHex: "#222222")
        try h.tags.create(name: "C", colorHex: "#333333")
        #expect(try h.tags.tags().map(\.name) == ["A", "B", "C"])
        #expect(try h.tags.tags().map(\.sortIndex) == [0, 1, 2])

        try h.tags.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(try h.tags.tags().map(\.name) == ["B", "C", "A"])
        #expect(try h.tags.tags().map(\.sortIndex) == [0, 1, 2])

        try h.tags.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(try h.tags.tags().map(\.name) == ["A", "B", "C"])
    }

    @Test("assign, update, and delete tags")
    func tagAssignment() throws {
        let h = try Harness()
        let tag = try h.tags.create(name: "Work", colorHex: "#EF4444")
        let migraine = Migraine(startDate: Date(), painLevel: 5, stressLevel: 5)
        try h.migraines.insert(migraine)

        try h.tags.setTags([tag], for: migraine)
        #expect(migraine.tags?.first?.id == tag.id)
        #expect(tag.migraineCount == 1)

        try h.tags.update(tag, name: "Office", colorHex: nil)
        #expect(tag.name == "Office")
        #expect(tag.colorHex == "#EF4444")

        try h.tags.delete(tag)
        #expect(try h.tags.tags().isEmpty)
        #expect(migraine.tags?.isEmpty ?? true)
    }

    // MARK: - Users

    @Test("user is a single row: replace, update, delete")
    func userLifecycle() throws {
        let h = try Harness()
        #expect(try h.users.currentUser() == nil)

        try h.users.replace(with: User(name: "Nick"))
        #expect(try h.users.currentUser()?.name == "Nick")

        try h.users.replace(with: User(name: "Nicholas"))
        #expect(try h.users.currentUser()?.name == "Nicholas")

        try h.users.update { $0.averageSleepHours = 6 }
        #expect(try h.users.currentUser()?.averageSleepHours == 6)

        try h.users.deleteUser()
        #expect(try h.users.currentUser() == nil)
        #expect(throws: PersistenceError.notFound) { try h.users.update { _ in } }
    }

    @Test("duplicate users from a CloudKit merge are folded to the oldest")
    func duplicateUsersFolded() throws {
        let h = try Harness()
        let context = h.container.mainContext
        context.insert(User(name: "First", createdAt: Date().addingTimeInterval(-100)))
        context.insert(User(name: "Second", createdAt: Date()))
        try context.save()

        #expect(try h.users.currentUser()?.name == "First")
        #expect(try context.fetchCount(FetchDescriptor<User>()) == 1)
    }

    // MARK: - Sample data (DEBUG)

    @Test("sample generator seeds tags and migraines with samples")
    func sampleData() throws {
        let h = try Harness()
        let generator = SampleMigraineData(migraines: h.migraines, tags: h.tags)

        try generator()

        let all = try h.migraines.migraines()
        #expect(all.count == 13)
        #expect(try h.tags.tags().count == 6)
        #expect(all.filter(\.isOngoing).count == 1)
        #expect(all.allSatisfy { ($0.intensitySamples ?? []).count >= 3 })
        #expect(all.allSatisfy { $0.weather != nil && $0.health != nil })
    }
}
