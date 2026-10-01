//
//  DefaultMigraineRepository.swift
//  MygraData
//
//  The SwiftData-backed `MigraineRepository`. Retains the container (a ModelContext does
//  not keep its container alive), seeds the first intensity sample on insert, throws typed
//  failures, and notifies the change stream after every successful write.
//

import Foundation
import SwiftData
import MygraCore
import os

@MainActor
public final class DefaultMigraineRepository: MigraineRepository {

    private let container: ModelContainer
    private let changeCenter: MigraineChangeCenter?

    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer, changeCenter: MigraineChangeCenter? = nil) {
        self.container = container
        self.changeCenter = changeCenter
    }

    // MARK: - Reads

    public func migraines() throws(PersistenceError) -> [Migraine] {
        let descriptor = FetchDescriptor<Migraine>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.migraine.error("Migraine fetch failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    public func migraine(withID id: UUID) throws(PersistenceError) -> Migraine? {
        var descriptor = FetchDescriptor<Migraine>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            Log.migraine.error("Migraine lookup failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    public func count() throws(PersistenceError) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<Migraine>())
        } catch {
            Log.migraine.error("Migraine count failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Writes

    public func insert(_ migraine: Migraine) throws(PersistenceError) {
        context.insert(migraine)

        // Every migraine starts with one sample at its initial levels so the intensity
        // chart has an origin.
        let initialSample = IntensitySample(
            timestamp: migraine.startDate,
            painLevel: migraine.painLevel,
            stressLevel: migraine.stressLevel,
            note: nil,
            parentMigraine: migraine
        )
        context.insert(initialSample)
        if migraine.intensitySamples == nil { migraine.intensitySamples = [] }
        migraine.intensitySamples?.append(initialSample)

        try save(operation: "insert migraine")
        changeCenter?.notify(.migraineLogged(migraine.id))
    }

    public func update(_ migraine: Migraine, configure: (Migraine) -> Void) throws(PersistenceError) {
        configure(migraine)
        try save(operation: "update migraine")
        changeCenter?.notify(.migraineUpdated(migraine.id))
    }

    public func delete(_ migraine: Migraine) throws(PersistenceError) {
        let id = migraine.id
        context.delete(migraine)
        try save(operation: "delete migraine")
        changeCenter?.notify(.migraineDeleted(id))
    }

    public func deleteAll() throws(PersistenceError) {
        Log.migraine.info("Deleting all migraines")
        do {
            for migraine in try context.fetch(FetchDescriptor<Migraine>()) {
                context.delete(migraine)
            }
        } catch {
            Log.migraine.error("Delete-all fetch failed: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(error.localizedDescription)
        }
        try save(operation: "delete all migraines")
        changeCenter?.notify(.bulk)
    }

    @discardableResult
    public func addIntensitySample(to migraine: Migraine, timestamp: Date, painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> IntensitySample {
        let sample = IntensitySample(
            timestamp: timestamp,
            painLevel: painLevel,
            stressLevel: stressLevel,
            note: note,
            parentMigraine: migraine
        )
        context.insert(sample)
        if migraine.intensitySamples == nil { migraine.intensitySamples = [] }
        migraine.intensitySamples?.append(sample)

        // The migraine's headline levels follow the latest sample.
        migraine.painLevel = painLevel
        migraine.stressLevel = stressLevel

        try save(operation: "add intensity sample")
        changeCenter?.notify(.migraineUpdated(migraine.id))
        return sample
    }

    public func removeIntensitySample(_ sample: IntensitySample, from migraine: Migraine) throws(PersistenceError) {
        migraine.intensitySamples?.removeAll { $0.id == sample.id }
        context.delete(sample)
        try save(operation: "remove intensity sample")
        changeCenter?.notify(.migraineUpdated(migraine.id))
    }

    // MARK: - Saving

    private func save(operation: String) throws(PersistenceError) {
        do {
            try context.save()
        } catch {
            Log.migraine.error("Failed to \(operation): \(error.localizedDescription)")
            throw .saveFailed(error.localizedDescription)
        }
    }
}
