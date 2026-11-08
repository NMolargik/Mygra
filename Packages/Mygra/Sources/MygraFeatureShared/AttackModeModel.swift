//
//  AttackModeModel.swift
//  MygraFeatureShared
//
//  The environment-injected surface for Attack Mode. Owns the state machine, the
//  presentation flag the app shell binds a full-screen cover to, and the four verbs
//  (start, set intensity, log a medication, end) behind the existing use-cases. Every
//  entry point (widgets, the Control, the Action button, Siri, deep links, the watch via
//  the phone relay) funnels through here, so "an attack is already active" behaves the
//  same everywhere. Ending hands the migraine to the finish-logging coordinator.
//

import Foundation
import Observation
import MygraCore
import MygraDesignSystem
import os

@MainActor
@Observable
public final class AttackModeModel: AttackModeActions {

    // MARK: - Dependencies

    @ObservationIgnored private let migraineData: MigraineDataModel
    @ObservationIgnored private let startUseCase: any StartAttack
    @ObservationIgnored private let intensityUseCase: any RecordAttackIntensity
    @ObservationIgnored private let medicationUseCase: any LogAttackMedication
    @ObservationIgnored private let endUseCase: any EndAttack
    @ObservationIgnored private let coordinator: FinishLoggingCoordinator
    @ObservationIgnored private let observeChanges: any ObserveMigraineChanges
    @ObservationIgnored private let toastManager: ToastManager
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    // MARK: - State

    /// Whether the full-screen Attack Mode cover is showing.
    public var isPresented = false
    public private(set) var machine = AttackStateMachine()
    /// Set when the finish-logging prompt is opened; the migraine's detail screen claims
    /// it and presents the pre-filled Modify sheet.
    public var finishRequestID: UUID?
    /// The last dose logged this session, for the quiet confirmation line.
    public private(set) var lastLoggedMedication: (medication: QuickMedication, date: Date)?

    public init(
        migraineData: MigraineDataModel,
        startAttack: any StartAttack,
        recordIntensity: any RecordAttackIntensity,
        logMedication: any LogAttackMedication,
        endAttack: any EndAttack,
        coordinator: FinishLoggingCoordinator,
        observeChanges: any ObserveMigraineChanges,
        toastManager: ToastManager
    ) {
        self.migraineData = migraineData
        self.startUseCase = startAttack
        self.intensityUseCase = recordIntensity
        self.medicationUseCase = logMedication
        self.endUseCase = endAttack
        self.coordinator = coordinator
        self.observeChanges = observeChanges
        self.toastManager = toastManager
        reconcile()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let stream = self?.observeChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                self.reconcile()
            }
        }
    }

    // MARK: - Derived

    public var ongoing: Migraine? { migraineData.ongoingMigraine }

    /// The current pain level snapped to the nearest big step.
    public var selectedLevel: Int? {
        ongoing.map { AttackIntensity.nearestLevel(to: $0.painLevel) }
    }

    /// The user's usual medications for one-tap logging.
    public var quickMedications: [QuickMedication] {
        QuickMedications.suggestions(from: migraineData.allMedicationDoses)
    }

    /// Ended attacks waiting for their deferred questions.
    public var pendingFinish: [FinishItem] { coordinator.pending }

    // MARK: - Entry

    /// The single entry used by widgets, the Control, the Action button, Siri, and deep
    /// links: starts an attack when none is active, then shows Attack Mode. Safe to call
    /// repeatedly; it never starts a second attack.
    public func enter() {
        guard let started = startAttack() else { return }
        _ = started
    }

    /// Shows Attack Mode for the ongoing attack without starting anything.
    public func present() {
        guard ongoing != nil else { return }
        isPresented = true
    }

    public func close() {
        isPresented = false
    }

    // MARK: - AttackModeActions

    @discardableResult
    public func startAttack() -> AttackStart? {
        let started: AttackStart?
        do {
            started = try startUseCase()
        } catch {
            Log.migraine.error("Attack start failed: \(error.localizedDescription)")
            toastManager.show(error: error)
            return nil
        }
        guard let started else { return nil }
        migraineData.refresh()
        handle(machine.apply(.start(id: started.id, at: started.startedAt)))
        return started
    }

    @discardableResult
    public func setIntensity(_ painLevel: Int) -> Bool {
        perform { () throws(PersistenceError) -> Bool in try intensityUseCase(painLevel: painLevel) }
    }

    @discardableResult
    public func logMedication(_ medication: QuickMedication) -> Bool {
        let logged = perform { () throws(PersistenceError) -> Bool in try medicationUseCase(medication, at: Date()) }
        if logged { lastLoggedMedication = (medication, Date()) }
        return logged
    }

    @discardableResult
    public func endAttack() -> Bool {
        let ended: AttackEnd?
        do {
            ended = try endUseCase(at: Date())
        } catch {
            Log.migraine.error("Attack end failed: \(error.localizedDescription)")
            toastManager.show(error: error)
            return false
        }
        guard let ended else { return false }
        migraineData.refresh()
        lastLoggedMedication = nil
        handle(machine.apply(.end(at: ended.endedAt)))
        return true
    }

    // MARK: - Finish logging

    /// The prompt was opened: forget its card and notification and ask the detail screen
    /// to present the Modify sheet.
    public func requestFinish(_ id: UUID) {
        coordinator.resolve(id)
        finishRequestID = id
    }

    /// The user chose "Not now": the item no longer needs a prompt.
    public func resolveFinish(_ id: UUID) {
        coordinator.resolve(id)
    }

    /// Settings changed. Turning the prompt off clears anything already queued.
    public func finishPromptSettingsChanged() {
        if !coordinator.settings.isEnabled { coordinator.cancelAll() }
    }

    // MARK: - Private

    private func perform(_ operation: () throws(PersistenceError) -> Bool) -> Bool {
        do {
            let done = try operation()
            if done { migraineData.refresh() }
            return done
        } catch {
            Log.migraine.error("Attack action failed: \(error.localizedDescription)")
            toastManager.show(error: error)
            return false
        }
    }

    /// Keeps the machine in step with the store (an attack ended or started elsewhere).
    private func reconcile() {
        let ongoing = migraineData.ongoingMigraine
        handle(machine.apply(.sync(ongoingID: ongoing?.id, startedAt: ongoing?.startDate)))
        coordinator.prune(existingIDs: Set(migraineData.migraines.map(\.id)))
    }

    private func handle(_ effects: [AttackEffect]) {
        for effect in effects {
            switch effect {
            case .presentAttackMode:
                isPresented = true
            case .dismissAttackMode:
                isPresented = false
            case .deferFinishLogging(let id, let endedAt):
                coordinator.attackEnded(id: id, endedAt: endedAt)
            }
        }
    }
}
