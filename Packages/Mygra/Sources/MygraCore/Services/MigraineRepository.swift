//
//  MigraineRepository.swift
//  MygraCore
//
//  The migraine data boundary (the old MigraineManager's CRUD, minus the presentation,
//  Live Activity, widget, HealthKit, Siri, and Spotlight coupling — those are now
//  policies reacting to the change stream). `DefaultMigraineRepository` in MygraData owns
//  the ModelContext, inserts the initial intensity sample, throws typed failures (the
//  old manager swallowed them), and notifies the change stream after every successful
//  write. Each verb gets a thin single-verb use-case so screens depend on exactly what
//  they use.
//

import Foundation

@MainActor
public protocol MigraineRepository: AnyObject {
    /// Every migraine, newest first.
    func migraines() throws(PersistenceError) -> [Migraine]

    /// The migraine with `id`, if it still exists.
    func migraine(withID id: UUID) throws(PersistenceError) -> Migraine?

    /// Total number of migraines in the store.
    func count() throws(PersistenceError) -> Int

    /// Persists a new migraine, seeding its first intensity sample from its levels.
    func insert(_ migraine: Migraine) throws(PersistenceError)

    /// Applies edits and persists.
    func update(_ migraine: Migraine, configure: (Migraine) -> Void) throws(PersistenceError)

    /// Deletes one migraine (cascades to its samples).
    func delete(_ migraine: Migraine) throws(PersistenceError)

    /// Deletes every migraine.
    func deleteAll() throws(PersistenceError)

    /// Appends an intensity sample and moves the migraine's current levels to it.
    @discardableResult
    func addIntensitySample(to migraine: Migraine, timestamp: Date, painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> IntensitySample

    /// Removes an intensity sample.
    func removeIntensitySample(_ sample: IntensitySample, from migraine: Migraine) throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadMigraines {
    func callAsFunction() throws(PersistenceError) -> [Migraine]
}

public struct LoadMigrainesUseCase: LoadMigraines {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [Migraine] {
        try repository.migraines()
    }
}

@MainActor
public protocol FindMigraine {
    func callAsFunction(withID id: UUID) throws(PersistenceError) -> Migraine?
}

public struct FindMigraineUseCase: FindMigraine {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    public func callAsFunction(withID id: UUID) throws(PersistenceError) -> Migraine? {
        try repository.migraine(withID: id)
    }
}

@MainActor
public protocol CountMigraines {
    func callAsFunction() throws(PersistenceError) -> Int
}

public struct CountMigrainesUseCase: CountMigraines {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> Int {
        try repository.count()
    }
}

/// The primary user action: "I have (had) a migraine." Persists the record, writes a
/// completed attack to Health, and lets Siri learn the action when it is ongoing.
@MainActor
public protocol LogMigraine {
    func callAsFunction(_ migraine: Migraine) throws(PersistenceError)
}

public struct LogMigraineUseCase: LogMigraine {
    private let repository: any MigraineRepository
    private let headaches: (any HeadacheRecording)?
    private let donor: (any IntentDonating)?

    public init(repository: any MigraineRepository, headaches: (any HeadacheRecording)? = nil, donor: (any IntentDonating)? = nil) {
        self.repository = repository
        self.headaches = headaches
        self.donor = donor
    }

    public func callAsFunction(_ migraine: Migraine) throws(PersistenceError) {
        try repository.insert(migraine)
        if migraine.isOngoing {
            donor?.donate(.startMigraine)
        } else if let end = migraine.endDate, let headaches {
            let start = migraine.startDate
            let severity = migraine.severity
            Task { try? await headaches.recordHeadache(start: start, end: end, severity: severity) }
        }
    }
}

/// Starts tracking a migraine right now (watch, Siri, Shortcuts). Refuses when one is
/// already ongoing and returns the new record's ID otherwise.
@MainActor
public protocol StartMigraine {
    @discardableResult
    func callAsFunction(painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> UUID?
}

public struct StartMigraineUseCase: StartMigraine {
    private let repository: any MigraineRepository
    private let log: any LogMigraine

    public init(repository: any MigraineRepository, log: any LogMigraine) {
        self.repository = repository
        self.log = log
    }

    @discardableResult
    public func callAsFunction(painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> UUID? {
        guard try repository.migraines().first(where: \.isOngoing) == nil else { return nil }
        let migraine = Migraine(startDate: Date(), endDate: nil, painLevel: painLevel, stressLevel: stressLevel, note: note)
        try log(migraine)
        return migraine.id
    }
}

@MainActor
public protocol UpdateMigraine {
    func callAsFunction(_ migraine: Migraine, configure: (Migraine) -> Void) throws(PersistenceError)
}

/// Applies edits. When the edit completes an ongoing migraine, the finished attack is
/// written to Health (the old manager did this inline in `update`).
public struct UpdateMigraineUseCase: UpdateMigraine {
    private let repository: any MigraineRepository
    private let headaches: (any HeadacheRecording)?

    public init(repository: any MigraineRepository, headaches: (any HeadacheRecording)? = nil) {
        self.repository = repository
        self.headaches = headaches
    }

    public func callAsFunction(_ migraine: Migraine, configure: (Migraine) -> Void) throws(PersistenceError) {
        let wasOngoing = migraine.isOngoing
        try repository.update(migraine, configure: configure)
        if wasOngoing, let end = migraine.endDate, let headaches {
            let start = migraine.startDate
            let severity = migraine.severity
            Task { try? await headaches.recordHeadache(start: start, end: end, severity: severity) }
        }
    }
}

/// Ends the ongoing migraine (in-app, watch, Siri). Returns whether one was ended.
@MainActor
public protocol EndOngoingMigraine {
    @discardableResult
    func callAsFunction(at endDate: Date) throws(PersistenceError) -> Bool
}

extension EndOngoingMigraine {
    @discardableResult
    public func callAsFunction() throws(PersistenceError) -> Bool {
        try callAsFunction(at: Date())
    }
}

public struct EndOngoingMigraineUseCase: EndOngoingMigraine {
    private let repository: any MigraineRepository
    private let update: any UpdateMigraine
    private let donor: (any IntentDonating)?

    public init(repository: any MigraineRepository, update: any UpdateMigraine, donor: (any IntentDonating)? = nil) {
        self.repository = repository
        self.update = update
        self.donor = donor
    }

    @discardableResult
    public func callAsFunction(at endDate: Date) throws(PersistenceError) -> Bool {
        guard let ongoing = try repository.migraines().first(where: \.isOngoing) else { return false }
        try update(ongoing) { $0.endDate = max(endDate, $0.startDate) }
        donor?.donate(.endMigraine)
        return true
    }
}

@MainActor
public protocol DeleteMigraine {
    func callAsFunction(_ migraine: Migraine) throws(PersistenceError)
}

public struct DeleteMigraineUseCase: DeleteMigraine {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    public func callAsFunction(_ migraine: Migraine) throws(PersistenceError) {
        try repository.delete(migraine)
    }
}

@MainActor
public protocol DeleteAllMigraines {
    func callAsFunction() throws(PersistenceError)
}

public struct DeleteAllMigrainesUseCase: DeleteAllMigraines {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) {
        try repository.deleteAll()
    }
}

@MainActor
public protocol RecordIntensitySample {
    @discardableResult
    func callAsFunction(for migraine: Migraine, painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> IntensitySample
}

public struct RecordIntensitySampleUseCase: RecordIntensitySample {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    @discardableResult
    public func callAsFunction(for migraine: Migraine, painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> IntensitySample {
        try repository.addIntensitySample(to: migraine, timestamp: Date(), painLevel: painLevel, stressLevel: stressLevel, note: note)
    }
}

@MainActor
public protocol RemoveIntensitySample {
    func callAsFunction(_ sample: IntensitySample, from migraine: Migraine) throws(PersistenceError)
}

public struct RemoveIntensitySampleUseCase: RemoveIntensitySample {
    private let repository: any MigraineRepository
    public init(repository: any MigraineRepository) { self.repository = repository }
    public func callAsFunction(_ sample: IntensitySample, from migraine: Migraine) throws(PersistenceError) {
        try repository.removeIntensitySample(sample, from: migraine)
    }
}

// MARK: - Sample data (DEBUG)

#if DEBUG
/// Seeds demo tags + migraines (Settings' developer menu). The concrete generator lives
/// in MygraData.
@MainActor
public protocol GenerateSampleData {
    func callAsFunction() throws(PersistenceError)
}
#endif
