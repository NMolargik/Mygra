//
//  MigraineUseCaseTests.swift
//  MygraCoreTests
//
//  The write-path use-cases over an in-memory repository and fake seams: logging writes
//  headaches for completed attacks and donates for ongoing ones; ending finds the
//  ongoing record; starting refuses duplicates.
//

import Foundation
import Testing
import MygraCore

@Suite("Migraine use-cases")
@MainActor
struct MigraineUseCaseTests {

    @Test func loggingCompletedMigraineRecordsHeadache() async throws {
        let repository = InMemoryMigraineRepository()
        let headaches = FakeHeadacheRecorder()
        let donor = FakeIntentDonor()
        let log = LogMigraineUseCase(repository: repository, headaches: headaches, donor: donor)

        let end = Date()
        try log(makeMigraine(start: end.addingTimeInterval(-3600), end: end, pain: 8))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(repository.storage.count == 1)
        #expect(headaches.recorded.count == 1)
        #expect(headaches.recorded.first?.severity == .high)
        #expect(donor.donated.isEmpty)
    }

    @Test func loggingOngoingMigraineDonatesStartIntent() async throws {
        let repository = InMemoryMigraineRepository()
        let headaches = FakeHeadacheRecorder()
        let donor = FakeIntentDonor()
        let log = LogMigraineUseCase(repository: repository, headaches: headaches, donor: donor)

        try log(makeMigraine())
        try? await Task.sleep(for: .milliseconds(50))

        #expect(headaches.recorded.isEmpty)
        #expect(donor.donated == [.startMigraine])
    }

    @Test func endingOngoingMigraineWritesHeadacheAndDonates() async throws {
        let repository = InMemoryMigraineRepository()
        let headaches = FakeHeadacheRecorder()
        let donor = FakeIntentDonor()
        let update = UpdateMigraineUseCase(repository: repository, headaches: headaches)
        let end = EndOngoingMigraineUseCase(repository: repository, update: update, donor: donor)
        let migraine = makeMigraine(start: Date().addingTimeInterval(-600))
        repository.storage = [migraine]

        #expect(try end())
        try? await Task.sleep(for: .milliseconds(50))
        #expect(migraine.endDate != nil)
        #expect(headaches.recorded.count == 1)
        #expect(donor.donated == [.endMigraine])

        // Nothing ongoing any more.
        #expect(try end() == false)
    }

    @Test func endDateNeverPrecedesStart() throws {
        let repository = InMemoryMigraineRepository()
        let end = EndOngoingMigraineUseCase(repository: repository, update: UpdateMigraineUseCase(repository: repository))
        let start = Date()
        let migraine = makeMigraine(start: start)
        repository.storage = [migraine]
        try end(at: start.addingTimeInterval(-3600))
        #expect(migraine.endDate == start)
    }

    @Test func startRefusesWhenOneIsOngoing() throws {
        let repository = InMemoryMigraineRepository()
        let start = StartMigraineUseCase(repository: repository, log: LogMigraineUseCase(repository: repository))

        let first = try start(painLevel: 6, stressLevel: 3, note: nil)
        #expect(first != nil)
        #expect(try start(painLevel: 4, stressLevel: 4, note: nil) == nil)
        #expect(repository.storage.count == 1)
    }

    @Test func repositoryErrorsPropagateTyped() {
        let repository = InMemoryMigraineRepository()
        repository.errorToThrow = .saveFailed("disk full")
        let log = LogMigraineUseCase(repository: repository)
        #expect(throws: PersistenceError.saveFailed("disk full")) {
            try log(makeMigraine())
        }
    }
}
