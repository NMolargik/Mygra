//
//  HealthManager.swift
//  MygraServices
//
//  HealthKit authorization, the aggregated `HealthData` snapshot for a window, intake
//  writes (water/caffeine/energy/sleep), and completed-headache writes. The store is a
//  protocol seam (`HealthStore`) so the manager is testable with a spy on device.
//

#if canImport(HealthKit) && !os(macOS)
import Foundation
import HealthKit
import Observation
import MygraCore
import os

nonisolated public enum HealthError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied
    case authorizationFailed(underlying: any Error)
    case snapshotFailed(underlying: any Error)
    case saveFailed(kind: String, underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: return String(localized: "Health data is unavailable on this device.")
        case .authorizationDenied: return String(localized: "Health access was not authorized.")
        case .authorizationFailed: return String(localized: "Failed to request Health authorization.")
        case .snapshotFailed: return String(localized: "Failed to fetch Health snapshot.")
        case .saveFailed(let kind, _): return String(localized: "Failed to save \(kind) to Health.")
        }
    }

    public var failureReason: String? {
        switch self {
        case .authorizationFailed(let underlying), .snapshotFailed(let underlying), .saveFailed(_, let underlying):
            return underlying.localizedDescription
        default:
            return nil
        }
    }
}

// MARK: - Store seam

nonisolated public protocol HealthStore: Sendable {
    static func isHealthDataAvailable() -> Bool
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func execute(_ query: HKQuery)
    func save(_ sample: HKSample) async throws
}

/// HKHealthStore is internally thread-safe for our usage patterns.
nonisolated public struct LiveHealthStore: HealthStore, @unchecked Sendable {
    private let inner = HKHealthStore()

    public init() {}

    public static func isHealthDataAvailable() -> Bool { HKHealthStore.isHealthDataAvailable() }
    public func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await inner.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus { inner.authorizationStatus(for: type) }
    public func execute(_ query: HKQuery) { inner.execute(query) }
    public func save(_ sample: HKSample) async throws { try await inner.save(sample) }
}

// MARK: - Query client

actor HealthQueryClient {
    private let store: any HealthStore

    init(store: any HealthStore) {
        self.store = store
    }

    func sumQuantity(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    continuation.resume(returning: 0)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
                }
            }
            store.execute(query)
        }
    }

    func averageQuantity(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    continuation.resume(returning: 0)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit) ?? 0)
                }
            }
            store.execute(query)
        }
    }

    func totalSleepHours(_ sleepType: HKCategoryType, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    continuation.resume(returning: 0)
                    return
                } else if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let asleep: Set<HKCategoryValueSleepAnalysis> = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]
                let totalSeconds = (samples as? [HKCategorySample])?
                    .filter { sample in
                        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                        return asleep.contains(value)
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }

    func inferMenstrualPhase(_ flowType: HKCategoryType?, from start: Date, to end: Date) async throws -> MenstrualPhase? {
        guard let flowType else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-28 * 24 * 3600), end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: flowType, predicate: predicate, limit: 50, sortDescriptors: [sort]) { _, samples, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    continuation.resume(returning: nil)
                    return
                } else if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let recent = (samples as? [HKCategorySample]) ?? []
                let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
                let hasRecentHeavy = recent.contains {
                    $0.endDate >= sevenDaysAgo && HKCategoryValueVaginalBleeding(rawValue: $0.value) == .heavy
                }
                if hasRecentHeavy {
                    continuation.resume(returning: .menstrual)
                } else if let lastFlow = recent.first {
                    let days = Calendar.current.dateComponents([.day], from: lastFlow.endDate, to: Date()).day ?? 0
                    switch days {
                    case 0...7: continuation.resume(returning: .menstrual)
                    case 8...14: continuation.resume(returning: .follicular)
                    case 15...18: continuation.resume(returning: .ovulatory)
                    default: continuation.resume(returning: .luteal)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(query)
        }
    }
}

// MARK: - Manager

@MainActor
@Observable
public final class HealthManager: HeadacheRecording {

    @ObservationIgnored private let store: any HealthStore
    @ObservationIgnored private let queryClient: HealthQueryClient

    public private(set) var isAuthorized = false
    public private(set) var lastError: (any Error)?
    /// The most recently fetched snapshot (cached for UI).
    public private(set) var latestData: HealthData?

    public init(store: any HealthStore) {
        self.store = store
        self.queryClient = HealthQueryClient(store: store)
        refreshAuthorizationStatus()
    }

    public convenience init() {
        self.init(store: LiveHealthStore())
    }

    // MARK: - Types

    private var qtWater: HKQuantityType { .quantityType(forIdentifier: .dietaryWater)! }
    private var qtCaffeine: HKQuantityType { .quantityType(forIdentifier: .dietaryCaffeine)! }
    private var qtEnergy: HKQuantityType { .quantityType(forIdentifier: .dietaryEnergyConsumed)! }
    private var qtSteps: HKQuantityType { .quantityType(forIdentifier: .stepCount)! }
    private var qtRestingHR: HKQuantityType { .quantityType(forIdentifier: .restingHeartRate)! }
    private var qtHR: HKQuantityType { .quantityType(forIdentifier: .heartRate)! }
    private var qtGlucose: HKQuantityType { .quantityType(forIdentifier: .bloodGlucose)! }
    private var qtBloodOxygen: HKQuantityType { .quantityType(forIdentifier: .oxygenSaturation)! }
    private var ctSleep: HKCategoryType { .categoryType(forIdentifier: .sleepAnalysis)! }
    private var ctHeadache: HKCategoryType { .categoryType(forIdentifier: .headache)! }
    private var ctMenstrualFlow: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .menstrualFlow) }
    private var ctOvulation: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .ovulationTestResult) }

    private let unitMilliliter = HKUnit.literUnit(with: .milli)
    private let unitMilligram = HKUnit.gramUnit(with: .milli)
    private let unitKilocalorie = HKUnit.kilocalorie()
    private let unitCount = HKUnit.count()
    private let unitBPM = HKUnit.count().unitDivided(by: HKUnit.minute())
    private let unitMgPerdL = HKUnit(from: "mg/dL")
    private let unitPercent = HKUnit.percent()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [qtWater, qtCaffeine, qtEnergy, qtSteps, qtRestingHR, qtHR, ctSleep, qtGlucose, qtBloodOxygen, ctHeadache]
        if let flow = ctMenstrualFlow { types.insert(flow) }
        if let ovulation = ctOvulation { types.insert(ovulation) }
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        [qtWater, qtCaffeine, qtEnergy, ctSleep, ctHeadache]
    }

    // MARK: - Authorization

    public func requestAuthorization() async {
        guard type(of: store).isHealthDataAvailable() else {
            lastError = HealthError.healthDataUnavailable
            isAuthorized = false
            Log.health.error("Health data unavailable on this device")
            return
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            updateAuthorizationFlag()
            lastError = nil
        } catch {
            isAuthorized = false
            lastError = HealthError.authorizationFailed(underlying: error)
            Log.health.error("requestAuthorization failed: \(error.localizedDescription)")
        }
    }

    /// Read access is "authorized" once every read type has been decided (HealthKit hides
    /// read denials; `.notDetermined` is the only observable signal).
    private func updateAuthorizationFlag() {
        let undecided = readTypes.contains { store.authorizationStatus(for: $0) == .notDetermined }
        isAuthorized = !undecided
        Log.health.info("Health authorization flag: \(self.isAuthorized)")
    }

    /// Re-reads the authorization state **without** prompting, so returning users are
    /// recognized at launch and the dashboard never surprises anyone with the system
    /// sheet. The only prompt paths are the explicit Connect Health buttons and saving a
    /// migraine that needs a Health snapshot.
    public func refreshAuthorizationStatus() {
        guard type(of: store).isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        updateAuthorizationFlag()
    }

    private func ensureAuthorized() async throws {
        if !isAuthorized {
            await requestAuthorization()
            if !isAuthorized {
                throw HealthError.authorizationDenied
            }
        }
    }

    // MARK: - Snapshots

    /// Aggregates samples within the window into one `HealthData` snapshot.
    public func fetchSnapshot(from start: Date, to end: Date) async throws -> HealthData {
        try await ensureAuthorized()

        async let waterML = queryClient.sumQuantity(qtWater, unit: unitMilliliter, from: start, to: end)
        async let caffeineMg = queryClient.sumQuantity(qtCaffeine, unit: unitMilligram, from: start, to: end)
        async let kcal = queryClient.sumQuantity(qtEnergy, unit: unitKilocalorie, from: start, to: end)
        async let steps = queryClient.sumQuantity(qtSteps, unit: unitCount, from: start, to: end)
        async let restingHR = queryClient.averageQuantity(qtRestingHR, unit: unitBPM, from: start, to: end)
        async let activeHR = queryClient.averageQuantity(qtHR, unit: unitBPM, from: start, to: end)
        async let glucose = queryClient.averageQuantity(qtGlucose, unit: unitMgPerdL, from: start, to: end)
        async let spo2 = queryClient.averageQuantity(qtBloodOxygen, unit: unitPercent, from: start, to: end)
        async let sleepHours = queryClient.totalSleepHours(ctSleep, from: start, to: end)
        async let phase = queryClient.inferMenstrualPhase(ctMenstrualFlow, from: start, to: end)

        let glucoseValue = try await glucose
        let spo2Value = try await spo2

        return HealthData(
            waterLiters: try await waterML / 1000.0,
            sleepHours: try await sleepHours,
            energyKilocalories: try await kcal,
            caffeineMg: try await caffeineMg,
            stepCount: Int(try await steps),
            restingHeartRate: Int((try await restingHR).rounded()),
            activeHeartRate: Int((try await activeHR).rounded()),
            glucoseMgPerdL: glucoseValue > 0 ? glucoseValue : nil,
            bloodOxygenPercent: spo2Value > 0 ? spo2Value : nil,
            menstrualPhase: try await phase
        )
    }

    /// A snapshot for the migraine's day (not cached).
    public func fetchSnapshot(forMigraineStart start: Date) async throws -> HealthData {
        let window = MigraineDates.healthWindow(forStart: start)
        return try await fetchSnapshot(from: window.start, to: window.end)
    }

    /// Refreshes `latestData` for a window; failures land in `lastError`. This is the
    /// passive path (dashboard, pull-to-refresh) — it never triggers the system
    /// authorization prompt; without access it simply clears the snapshot.
    public func refreshLatest(from start: Date, to end: Date) async {
        refreshAuthorizationStatus()
        guard isAuthorized else {
            latestData = nil
            return
        }
        do {
            latestData = try await fetchSnapshot(from: start, to: end)
            lastError = nil
        } catch {
            Log.health.error("Refresh of Health data failed: \(error.localizedDescription)")
            latestData = nil
            lastError = HealthError.snapshotFailed(underlying: error)
        }
    }

    /// Refreshes `latestData` for today (midnight to now).
    public func refreshLatestForToday(calendar: Calendar = .current) async {
        let now = Date()
        await refreshLatest(from: calendar.startOfDay(for: now), to: now)
    }

    /// Refreshes `latestData` for the migraine's day.
    public func refreshLatest(forMigraineStart start: Date) async {
        let window = MigraineDates.healthWindow(forStart: start)
        await refreshLatest(from: window.start, to: window.end)
    }

    // MARK: - Writes

    public func saveWater(liters: Double, on date: Date = Date()) async throws {
        try await ensureAuthorized()
        let quantity = HKQuantity(unit: unitMilliliter, doubleValue: liters * 1000.0)
        try await store.save(HKQuantitySample(type: qtWater, quantity: quantity, start: date, end: date))
    }

    public func saveCaffeine(mg: Double, on date: Date = Date()) async throws {
        try await ensureAuthorized()
        let quantity = HKQuantity(unit: unitMilligram, doubleValue: mg)
        try await store.save(HKQuantitySample(type: qtCaffeine, quantity: quantity, start: date, end: date))
    }

    public func saveEnergy(kcal: Double, on date: Date = Date()) async throws {
        try await ensureAuthorized()
        let quantity = HKQuantity(unit: unitKilocalorie, doubleValue: kcal)
        try await store.save(HKQuantitySample(type: qtEnergy, quantity: quantity, start: date, end: date))
    }

    /// Saves a simple sleep interval (asleep-unspecified).
    public func saveSleep(from start: Date, to end: Date) async throws {
        try await ensureAuthorized()
        let sample = HKCategorySample(type: ctSleep, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: start, end: end)
        try await store.save(sample)
    }

    /// Writes every non-zero staged addition as samples ending at `date` (sleep as an
    /// interval ending there). Amounts are rounded to Health precision.
    public func save(_ additions: IntakeAdditions, on date: Date = Date()) async throws {
        if additions.waterLiters > 0 {
            try await saveWater(liters: (additions.waterLiters * 1000).rounded() / 1000, on: date)
        }
        if additions.caffeineMg > 0 {
            try await saveCaffeine(mg: additions.caffeineMg.rounded(), on: date)
        }
        if additions.foodKilocalories > 0 {
            try await saveEnergy(kcal: additions.foodKilocalories.rounded(), on: date)
        }
        if additions.sleepHours > 0 {
            try await saveSleep(from: date.addingTimeInterval(-additions.sleepHours * 3600.0), to: date)
        }
    }

    // MARK: - Headaches

    private func headacheValue(for severity: Severity) -> HKCategoryValueSeverity {
        switch severity {
        case .low: return .mild
        case .medium: return .moderate
        case .high: return .severe
        }
    }

    /// Saves a completed headache. HealthKit requires both dates; never call for ongoing attacks.
    public func recordHeadache(start: Date, end: Date, severity: Severity) async throws {
        do {
            try await ensureAuthorized()
            let sample = HKCategorySample(type: ctHeadache, value: headacheValue(for: severity).rawValue, start: start, end: end)
            try await store.save(sample)
        } catch {
            Log.health.error("Failed to save headache: \(error.localizedDescription)")
            lastError = HealthError.saveFailed(kind: "headache", underlying: error)
            throw error
        }
    }
}
#endif
