//
//  AttackModeTests.swift
//  MygraCoreTests
//
//  Attack Mode logic: intensity steps, the dim palette guarantees, quick-medication
//  ranking, the start/active/end state machine, the finish-logging policy and
//  coordinator, the use-cases, and the shared-status wire form the watch relies on.
//

import Foundation
import Testing
import MygraCore

@MainActor
final class FakeNotificationScheduler: LocalNotificationScheduling {
    struct Scheduled: Equatable { let identifier: String; let fireDate: Date; let url: String? }
    private(set) var scheduled: [Scheduled] = []
    private(set) var cancelled: [String] = []
    func schedule(title: String, body: String, identifier: String, fireDate: Date, userInfo: [String: String]) async throws {
        scheduled.append(Scheduled(identifier: identifier, fireDate: fireDate, url: userInfo["url"]))
    }
    func cancel(identifiers: [String]) { cancelled.append(contentsOf: identifiers) }
}

@Suite("Attack Mode: intensity and palette")
struct AttackPaletteTests {
    @Test func nearestLevelSnapsToBigSteps() {
        #expect(AttackIntensity.nearestLevel(to: 0) == 2)
        #expect(AttackIntensity.nearestLevel(to: 3) == 4)   // tie rounds up
        #expect(AttackIntensity.nearestLevel(to: 5) == 6)
        #expect(AttackIntensity.nearestLevel(to: 7) == 8)
        #expect(AttackIntensity.nearestLevel(to: 10) == 10)
        #expect(AttackIntensity.nearestLevel(to: 99) == 10)
        #expect(AttackIntensity.nearestLevel(to: -4) == 2)
    }

    @Test func nothingIsBright() {
        for token in AttackPalette.allTokens {
            #expect(token.brightestChannel <= 0.75)
            #expect(token.luminance <= 0.25)
        }
        #expect(AttackPalette.background.luminance < 0.01)
    }

    @Test func textIsWarmAndLowSaturation() {
        for text in [AttackPalette.primaryText, AttackPalette.secondaryText, AttackPalette.endText] {
            #expect(text.red >= text.green && text.green >= text.blue)
            #expect(text.saturation <= 0.6)
        }
    }

    @Test func textStaysReadable() {
        #expect(AttackPalette.primaryText.contrast(with: AttackPalette.background) >= 4.5)
        #expect(AttackPalette.primaryText.contrast(with: AttackPalette.buttonFill) >= 4.5)
        #expect(AttackPalette.secondaryText.contrast(with: AttackPalette.background) >= 3)
        #expect(AttackPalette.endText.contrast(with: AttackPalette.endFill) >= 4.5)
    }
}

@Suite("Attack Mode: quick medications")
@MainActor
struct QuickMedicationTests {
    private func dose(_ name: String, _ amount: String, daysAgo: Double, cls: MedicationClass = .triptan) -> MedicationDose {
        MedicationDose(name: name, medicationClass: cls, dose: amount, takenAt: Date().addingTimeInterval(-daysAgo * 86_400))
    }

    @Test func ranksByCountThenRecency() {
        let doses = [
            dose("Sumatriptan", "50 mg", daysAgo: 20), dose("Sumatriptan", "50 mg", daysAgo: 10), dose("sumatriptan", "50 mg", daysAgo: 1),
            dose("Ibuprofen", "400 mg", daysAgo: 2, cls: .simpleAnalgesic), dose("Naproxen", "220 mg", daysAgo: 3, cls: .simpleAnalgesic),
        ]
        let result = QuickMedications.suggestions(from: doses)
        #expect(result.map(\.label) == ["sumatriptan 50 mg", "Ibuprofen 400 mg", "Naproxen 220 mg"])
    }

    @Test func differentDosesAreSeparateEntries() {
        let doses = [dose("Sumatriptan", "50 mg", daysAgo: 5), dose("Sumatriptan", "100 mg", daysAgo: 1)]
        #expect(QuickMedications.suggestions(from: doses).map(\.dose) == ["100 mg", "50 mg"])
    }

    @Test func respectsLimitAndFallsBackWithoutHistory() {
        let many = (0..<8).map { dose("Med\($0)", "", daysAgo: Double($0)) }
        #expect(QuickMedications.suggestions(from: many, limit: 3).count == 3)
        let fallback = QuickMedications.suggestions(from: [])
        #expect(!fallback.isEmpty)
        #expect(fallback.allSatisfy { $0.dose.isEmpty })
    }

    @Test func wirePayloadRoundTrips() throws {
        let med = QuickMedication(name: "Rizatriptan", medicationClass: .triptan, dose: "10 mg")
        let decoded = try #require(QuickMedication(payload: med.payload))
        #expect(decoded == med)
        #expect(QuickMedication(payload: [:]) == nil)
    }
}

@Suite("Attack Mode: state machine")
struct AttackStateMachineTests {
    private let id = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func entryOpensExistingInsteadOfStartingSecond() {
        #expect(AttackEntry.resolve(ongoingID: nil) == .startNew)
        #expect(AttackEntry.resolve(ongoingID: id) == .openExisting(id))
    }

    @Test func startThenEndWalksTheLifecycle() {
        var machine = AttackStateMachine()
        #expect(machine.apply(.start(id: id, at: t0)) == [.presentAttackMode])
        #expect(machine.phase == .active(id: id, startedAt: t0))

        let end = t0.addingTimeInterval(3600)
        #expect(machine.apply(.end(at: end)) == [.dismissAttackMode, .deferFinishLogging(id: id, endedAt: end)])
        #expect(machine.phase == .idle)
    }

    @Test func secondStartKeepsTheActiveAttack() {
        var machine = AttackStateMachine()
        machine.apply(.start(id: id, at: t0))
        #expect(machine.apply(.start(id: UUID(), at: t0.addingTimeInterval(60))) == [.presentAttackMode])
        #expect(machine.phase.activeID == id)
    }

    @Test func endingWhileIdleDoesNothing() {
        var machine = AttackStateMachine()
        #expect(machine.apply(.end(at: t0)).isEmpty)
        #expect(machine.phase == .idle)
    }

    @Test func syncAdoptsAnAttackStartedElsewhereWithoutPresenting() {
        var machine = AttackStateMachine()
        #expect(machine.apply(.sync(ongoingID: id, startedAt: t0)).isEmpty)
        #expect(machine.phase == .active(id: id, startedAt: t0))
    }

    @Test func attackEndedElsewhereDismissesWithoutDeferredPrompt() {
        var machine = AttackStateMachine(phase: .active(id: id, startedAt: t0))
        #expect(machine.apply(.sync(ongoingID: nil, startedAt: nil)) == [.dismissAttackMode])
        #expect(machine.phase == .idle)
    }

    @Test func syncKeepsSameAttackQuietly() {
        var machine = AttackStateMachine(phase: .active(id: id, startedAt: t0))
        #expect(machine.apply(.sync(ongoingID: id, startedAt: t0)).isEmpty)
    }
}

@Suite("Attack Mode: finish-logging policy")
@MainActor
struct FinishLoggingTests {
    private let ended = Date(timeIntervalSince1970: 2_000_000)

    @Test func defaultsToEnabledWithTwoHours() {
        let settings = FinishLoggingSettings(defaults: FakeKeyValueStore())
        #expect(settings.isEnabled)
        #expect(settings.delayMinutes == 120)
        #expect(settings.delay == 7200)
    }

    @Test func readsAndClampsStoredValues() {
        let store = FakeKeyValueStore()
        store.set(false, forKey: AppStorageKeys.attackFinishPromptEnabled)
        store.set(30, forKey: AppStorageKeys.attackFinishPromptDelayMinutes)
        #expect(FinishLoggingSettings(defaults: store) == FinishLoggingSettings(isEnabled: false, delayMinutes: 30))
        #expect(FinishLoggingSettings(isEnabled: true, delayMinutes: 0).delayMinutes == 1)
        #expect(FinishLoggingSettings(isEnabled: true, delayMinutes: 99_999).delayMinutes == 1440)
    }

    @Test func plansFireDateAfterTheDelayAndNothingWhenOff() {
        let plan = FinishLoggingPlanner.plan(endedAt: ended, now: ended, settings: FinishLoggingSettings(delayMinutes: 60))
        #expect(plan?.fireDate == ended.addingTimeInterval(3600))
        #expect(plan?.showsCard == true)
        #expect(FinishLoggingPlanner.plan(endedAt: ended, now: ended, settings: FinishLoggingSettings(isEnabled: false)) == nil)
    }

    @Test func lateEndNeverSchedulesIntoThePast() {
        let now = ended.addingTimeInterval(3 * 3600)
        let plan = FinishLoggingPlanner.plan(endedAt: ended, now: now, settings: FinishLoggingSettings())
        #expect(plan?.fireDate == now.addingTimeInterval(5))
    }

    @Test func coordinatorSchedulesPersistsAndResolves() async {
        let store = FakeKeyValueStore()
        let scheduler = FakeNotificationScheduler()
        let coordinator = FinishLoggingCoordinator(defaults: store, scheduler: scheduler, now: { self.ended })
        let id = UUID()

        #expect(coordinator.attackEnded(id: id, endedAt: ended) != nil)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.pending.map(\.id) == [id])
        #expect(scheduler.scheduled == [.init(identifier: FinishLoggingCoordinator.notificationIdentifier(for: id), fireDate: ended.addingTimeInterval(7200), url: DeepLink.finishLogging(id).url.absoluteString)])

        // A relaunch sees the same pending item.
        #expect(FinishLoggingCoordinator(defaults: store).pending.map(\.id) == [id])

        coordinator.resolve(id)
        #expect(coordinator.pending.isEmpty)
        #expect(scheduler.cancelled == [FinishLoggingCoordinator.notificationIdentifier(for: id)])
        #expect(FinishLoggingCoordinator(defaults: store).pending.isEmpty)
    }

    @Test func disabledSettingSchedulesNothing() async {
        let store = FakeKeyValueStore()
        store.set(false, forKey: AppStorageKeys.attackFinishPromptEnabled)
        let scheduler = FakeNotificationScheduler()
        let coordinator = FinishLoggingCoordinator(defaults: store, scheduler: scheduler, now: { self.ended })
        #expect(coordinator.attackEnded(id: UUID(), endedAt: ended) == nil)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(coordinator.pending.isEmpty)
        #expect(scheduler.scheduled.isEmpty)
    }

    @Test func cancelAllAndPruneClearOutstandingItems() async {
        let scheduler = FakeNotificationScheduler()
        let coordinator = FinishLoggingCoordinator(defaults: FakeKeyValueStore(), scheduler: scheduler, now: { self.ended })
        let kept = UUID(), gone = UUID()
        coordinator.attackEnded(id: kept, endedAt: ended)
        coordinator.attackEnded(id: gone, endedAt: ended.addingTimeInterval(1))

        coordinator.prune(existingIDs: [kept])
        #expect(coordinator.pending.map(\.id) == [kept])
        #expect(scheduler.cancelled == [FinishLoggingCoordinator.notificationIdentifier(for: gone)])

        coordinator.cancelAll()
        #expect(coordinator.pending.isEmpty)
    }
}

@Suite("Attack Mode: use-cases")
@MainActor
struct AttackUseCaseTests {
    private func makeStack() -> (InMemoryMigraineRepository, StartAttackUseCase, RecordAttackIntensityUseCase, LogAttackMedicationUseCase, EndAttackUseCase) {
        let repository = InMemoryMigraineRepository()
        let log = LogMigraineUseCase(repository: repository)
        let start = StartAttackUseCase(repository: repository, start: StartMigraineUseCase(repository: repository, log: log))
        let intensity = RecordAttackIntensityUseCase(repository: repository, record: RecordIntensitySampleUseCase(repository: repository))
        let medication = LogAttackMedicationUseCase(repository: repository, log: LogMedicationUseCase(repository: repository))
        let update = UpdateMigraineUseCase(repository: repository)
        let end = EndAttackUseCase(repository: repository, end: EndOngoingMigraineUseCase(repository: repository, update: update))
        return (repository, start, intensity, medication, end)
    }

    @Test func startCreatesOneOngoingAttackAndReopensIt() throws {
        let (repository, start, _, _, _) = makeStack()
        let first = try #require(try start())
        #expect(!first.wasAlreadyActive)
        let second = try #require(try start())
        #expect(second.wasAlreadyActive)
        #expect(second.id == first.id)
        #expect(repository.storage.count == 1)
        #expect(repository.storage[0].isOngoing)
    }

    @Test func intensityAndMedicationNeedAnOngoingAttack() throws {
        let (_, _, intensity, medication, _) = makeStack()
        #expect(try intensity(painLevel: 6) == false)
        #expect(try medication(QuickMedication(name: "Ibuprofen", medicationClass: .simpleAnalgesic), at: Date()) == false)
    }

    @Test func intensityMovesPainAndKeepsStress() throws {
        let (repository, start, intensity, _, _) = makeStack()
        try start()
        #expect(try intensity(painLevel: 8))
        #expect(repository.storage[0].painLevel == 8)
        #expect(repository.storage[0].stressLevel == StartAttackUseCase.defaultLevel)
        #expect(try intensity(painLevel: 40))
        #expect(repository.storage[0].painLevel == 10)
    }

    @Test func medicationRecordsDoseWithDosage() throws {
        let (repository, start, _, medication, _) = makeStack()
        try start()
        let med = QuickMedication(name: "Sumatriptan", medicationClass: .triptan, dose: "50 mg")
        #expect(try medication(med, at: Date()))
        let dose = try #require(repository.storage[0].medications?.first)
        #expect(dose.name == "Sumatriptan")
        #expect(dose.dose == "50 mg")
        #expect(dose.medicationClass == .triptan)
    }

    @Test func endClosesTheAttackOnce() throws {
        let (repository, start, _, _, end) = makeStack()
        let started = try #require(try start())
        let ended = try #require(try end(at: Date()))
        #expect(ended.id == started.id)
        #expect(!repository.storage[0].isOngoing)
        #expect(try end(at: Date()) == nil)
    }
}

@Suite("Attack Mode: shared status for the watch")
@MainActor
struct AttackStatusTests {
    @Test func payloadCarriesPainAndMedications() throws {
        let meds = [QuickMedication(name: "Ibuprofen", medicationClass: .simpleAnalgesic, dose: "400 mg")]
        let status = SharedMigraineStatus(lastMigraineStart: Date(), hasOngoingMigraine: true, currentPainLevel: 7, quickMedications: meds)
        let decoded = try #require(SharedMigraineStatus(payload: status.payload))
        #expect(decoded.currentPainLevel == 7)
        #expect(decoded.quickMedications == meds)
    }

    @Test func defaultsRoundTripForWidgets() {
        let store = FakeKeyValueStore()
        let meds = [QuickMedication(name: "Sumatriptan", medicationClass: .triptan)]
        store.writeSharedStatus(SharedMigraineStatus(lastMigraineStart: Date(), hasOngoingMigraine: true, currentPainLevel: 4, quickMedications: meds))
        let read = store.readSharedStatus()
        #expect(read.currentPainLevel == 4)
        #expect(read.quickMedications == meds)
        store.writeSharedStatus(.empty)
        #expect(store.readSharedStatus() == .empty)
    }

    @Test func wireMessageCarriesMedication() throws {
        let med = QuickMedication(name: "Naproxen", medicationClass: .simpleAnalgesic, dose: "220 mg")
        let message = WatchMessage(command: .logMedication, medication: med)
        let decoded = WatchMessage(payload: message.payload)
        #expect(decoded.command == .logMedication)
        #expect(decoded.medication == med)
        #expect(WatchMessage(payload: WatchMessage(command: .setIntensity, painLevel: 8).payload).painLevel == 8)
    }
}
