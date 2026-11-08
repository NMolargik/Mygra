//
//  AttackModeUseCases.swift
//  MygraCore
//
//  The verbs behind Attack Mode, each a single-verb use-case over the existing
//  repository and use-cases: start (or surface the active attack), record an intensity
//  step, log a quick medication, and end. Ending hands the migraine to
//  `FinishLoggingCoordinator`, which defers every question the normal flow would ask.
//

import Foundation
import Observation

// MARK: - Start

public struct AttackStart: Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    /// True when an attack was already active: entry points open it, never a second.
    public let wasAlreadyActive: Bool
}

@MainActor
public protocol StartAttack {
    @discardableResult
    func callAsFunction() throws(PersistenceError) -> AttackStart?
}

public struct StartAttackUseCase: StartAttack {
    /// Pain and stress for a freshly started attack; the first intensity step replaces them.
    public static let defaultLevel = 5

    private let repository: any MigraineRepository
    private let start: any StartMigraine

    public init(repository: any MigraineRepository, start: any StartMigraine) {
        self.repository = repository
        self.start = start
    }

    @discardableResult
    public func callAsFunction() throws(PersistenceError) -> AttackStart? {
        let existing = try repository.migraines().first(where: \.isOngoing)
        switch AttackEntry.resolve(ongoingID: existing?.id) {
        case .openExisting:
            guard let existing else { return nil }
            return AttackStart(id: existing.id, startedAt: existing.startDate, wasAlreadyActive: true)
        case .startNew:
            guard let id = try start(painLevel: Self.defaultLevel, stressLevel: Self.defaultLevel, note: nil),
                  let created = try repository.migraine(withID: id) else { return nil }
            return AttackStart(id: id, startedAt: created.startDate, wasAlreadyActive: false)
        }
    }
}

// MARK: - Intensity

@MainActor
public protocol RecordAttackIntensity {
    /// Records an intensity sample on the ongoing attack. False when none is ongoing.
    @discardableResult
    func callAsFunction(painLevel: Int) throws(PersistenceError) -> Bool
}

public struct RecordAttackIntensityUseCase: RecordAttackIntensity {
    private let repository: any MigraineRepository
    private let record: any RecordIntensitySample

    public init(repository: any MigraineRepository, record: any RecordIntensitySample) {
        self.repository = repository
        self.record = record
    }

    @discardableResult
    public func callAsFunction(painLevel: Int) throws(PersistenceError) -> Bool {
        guard let ongoing = try repository.migraines().first(where: \.isOngoing) else { return false }
        try record(for: ongoing, painLevel: min(10, max(0, painLevel)), stressLevel: ongoing.stressLevel, note: nil)
        return true
    }
}

// MARK: - Medication

@MainActor
public protocol LogAttackMedication {
    /// Logs `medication` as taken at `date` on the ongoing attack. False when none is ongoing.
    @discardableResult
    func callAsFunction(_ medication: QuickMedication, at date: Date) throws(PersistenceError) -> Bool
}

public struct LogAttackMedicationUseCase: LogAttackMedication {
    private let repository: any MigraineRepository
    private let log: any LogMedication

    public init(repository: any MigraineRepository, log: any LogMedication) {
        self.repository = repository
        self.log = log
    }

    @discardableResult
    public func callAsFunction(_ medication: QuickMedication, at date: Date) throws(PersistenceError) -> Bool {
        guard let ongoing = try repository.migraines().first(where: \.isOngoing) else { return false }
        try log(for: ongoing, name: medication.name, medicationClass: medication.medicationClass, dose: medication.dose, takenAt: max(date, ongoing.startDate))
        return true
    }
}

// MARK: - End

public struct AttackEnd: Equatable, Sendable {
    public let id: UUID
    public let endedAt: Date
}

@MainActor
public protocol EndAttack {
    @discardableResult
    func callAsFunction(at endDate: Date) throws(PersistenceError) -> AttackEnd?
}

public struct EndAttackUseCase: EndAttack {
    private let repository: any MigraineRepository
    private let end: any EndOngoingMigraine

    public init(repository: any MigraineRepository, end: any EndOngoingMigraine) {
        self.repository = repository
        self.end = end
    }

    @discardableResult
    public func callAsFunction(at endDate: Date) throws(PersistenceError) -> AttackEnd? {
        guard let ongoing = try repository.migraines().first(where: \.isOngoing) else { return nil }
        let id = ongoing.id
        guard try end(at: endDate) else { return nil }
        return AttackEnd(id: id, endedAt: max(endDate, ongoing.startDate))
    }
}

// MARK: - Deferred finish-logging

/// Remembers which ended attacks still owe their deferred questions, schedules the gentle
/// notification for each, and exposes them for the in-app "Finish logging" card.
@MainActor
@Observable
public final class FinishLoggingCoordinator {
    /// Attacks waiting to be finished, oldest first.
    public private(set) var pending: [FinishItem]

    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private let scheduler: (any LocalNotificationScheduling)?
    @ObservationIgnored private let now: () -> Date

    public init(
        defaults: any KeyValueStoring,
        scheduler: (any LocalNotificationScheduling)? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.scheduler = scheduler
        self.now = now
        self.pending = Self.load(from: defaults)
    }

    public static func notificationIdentifier(for id: UUID) -> String {
        "attack.finishLogging.\(id.uuidString)"
    }

    /// The current user setting (read fresh so Settings changes apply to the next attack).
    public var settings: FinishLoggingSettings { FinishLoggingSettings(defaults: defaults) }

    /// Plans and records the deferred prompt for an attack that just ended.
    @discardableResult
    public func attackEnded(id: UUID, endedAt: Date) -> FinishLoggingPlan? {
        guard let plan = FinishLoggingPlanner.plan(endedAt: endedAt, now: now(), settings: settings) else { return nil }
        pending.removeAll { $0.id == id }
        pending.append(FinishItem(id: id, endedAt: endedAt, dueDate: plan.fireDate))
        pending.sort { $0.endedAt < $1.endedAt }
        persist()

        if let scheduler {
            let identifier = Self.notificationIdentifier(for: id)
            let url = DeepLink.finishLogging(id).url.absoluteString
            let fireDate = plan.fireDate
            Task {
                try? await scheduler.schedule(
                    title: String(localized: "Finish logging your migraine"),
                    body: String(localized: "When you feel up to it, add triggers and notes while you still remember."),
                    identifier: identifier,
                    fireDate: fireDate,
                    userInfo: ["url": url]
                )
            }
        }
        return plan
    }

    /// The user answered the questions (or chose to skip them): forget the item and its notification.
    public func resolve(_ id: UUID) {
        guard pending.contains(where: { $0.id == id }) else { return }
        pending.removeAll { $0.id == id }
        persist()
        scheduler?.cancel(identifiers: [Self.notificationIdentifier(for: id)])
    }

    /// The prompt was turned off in Settings: clear everything outstanding.
    public func cancelAll() {
        let identifiers = pending.map { Self.notificationIdentifier(for: $0.id) }
        pending = []
        persist()
        scheduler?.cancel(identifiers: identifiers)
    }

    /// Drops items whose migraine no longer exists (deleted, or removed by sync).
    public func prune(existingIDs: Set<UUID>) {
        let stale = pending.filter { !existingIDs.contains($0.id) }
        guard !stale.isEmpty else { return }
        pending.removeAll { item in stale.contains(where: { $0.id == item.id }) }
        persist()
        scheduler?.cancel(identifiers: stale.map { Self.notificationIdentifier(for: $0.id) })
    }

    private func persist() {
        if pending.isEmpty {
            defaults.removeObject(forKey: AppStorageKeys.attackPendingFinishItems)
        } else {
            defaults.set(try? JSONEncoder().encode(pending), forKey: AppStorageKeys.attackPendingFinishItems)
        }
    }

    private static func load(from defaults: any KeyValueStoring) -> [FinishItem] {
        defaults.data(forKey: AppStorageKeys.attackPendingFinishItems)
            .flatMap { try? JSONDecoder().decode([FinishItem].self, from: $0) } ?? []
    }
}

// MARK: - Actions surface

/// What entry points other than the Attack Mode screen (the watch, via the phone relay)
/// can ask for. Implemented by the shared attack model so every path uses one state machine.
@MainActor
public protocol AttackModeActions: AnyObject {
    @discardableResult func startAttack() -> AttackStart?
    @discardableResult func setIntensity(_ painLevel: Int) -> Bool
    @discardableResult func logMedication(_ medication: QuickMedication) -> Bool
    @discardableResult func endAttack() -> Bool
}
