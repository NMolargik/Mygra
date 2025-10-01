//
//  HealthManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import HealthKit

protocol HealthStore: Sendable {
    static func isHealthDataAvailable() -> Bool
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
    func statusForAuthorizationRequest(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func execute(_ query: HKQuery)
    func save(_ sample: HKSample) async throws
}

// LiveHealthStore is used across actors via HealthQueryClient; mark as unchecked Sendable.
// HKHealthStore is internally thread-safe for our usage patterns.
struct LiveHealthStore: HealthStore, @unchecked Sendable {
    static func isHealthDataAvailable() -> Bool { HKHealthStore.isHealthDataAvailable() }
    private let inner = HKHealthStore()
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await inner.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    func statusForAuthorizationRequest(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        try await inner.statusForAuthorizationRequest(toShare: typesToShare, read: typesToRead)
    }
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        inner.authorizationStatus(for: type)
    }
    func execute(_ query: HKQuery) { inner.execute(query) }
    func save(_ sample: HKSample) async throws { try await inner.save(sample) }
}

actor HealthQueryClient {
    let store: HealthStore

    init(store: HealthStore) {
        self.store = store
    }

    func sumQuantity(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    cont.resume(returning: 0.0)
                    return
                } else if let error {
                    cont.resume(throwing: error)
                    return
                }
                let total = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: total)
            }
            self.store.execute(query)
        }
    }

    func averageQuantity(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    cont.resume(returning: 0.0)
                    return
                } else if let error {
                    cont.resume(throwing: error)
                    return
                }
                let avg = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: avg)
            }
            self.store.execute(query)
        }
    }

    func totalSleepHours(ctSleep: HKCategoryType, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: ctSleep, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    cont.resume(returning: 0.0)
                    return
                } else if let error {
                    cont.resume(throwing: error)
                    return
                }

                let totalSeconds = (samples as? [HKCategorySample])?
                    .filter { sample in
                        let v = HKCategoryValueSleepAnalysis(rawValue: sample.value) ?? .inBed
                        return v == .asleepUnspecified || v == .asleepCore || v == .asleepDeep || v == .asleepREM
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0.0

                cont.resume(returning: totalSeconds / 3600.0)
            }
            self.store.execute(query)
        }
    }

    func inferMenstrualPhase(ctMenstrualFlow: HKCategoryType?, from start: Date, to end: Date) async throws -> MenstrualPhase? {
        guard let flowType = ctMenstrualFlow else { return nil }

        return try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-28*24*3600), end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: flowType, predicate: predicate, limit: 50, sortDescriptors: [sort]) { _, samples, error in
                if let hkError = error as? HKError, hkError.code == .errorNoData {
                    cont.resume(returning: nil)
                    return
                } else if let error {
                    cont.resume(throwing: error)
                    return
                }

                let recent = (samples as? [HKCategorySample]) ?? []

                let sevenDaysAgo = Date().addingTimeInterval(-7*24*3600)
                let hasRecentHeavy = recent.contains {
                    $0.endDate >= sevenDaysAgo &&
                    HKCategoryValueVaginalBleeding(rawValue: $0.value) == .heavy
                }

                if hasRecentHeavy {
                    cont.resume(returning: .menstrual)
                } else {
                    if let lastFlow = recent.first {
                        let days = Calendar.current.dateComponents([.day], from: lastFlow.endDate, to: Date()).day ?? 0
                        switch days {
                        case 0...7: cont.resume(returning: .menstrual)
                        case 8...14: cont.resume(returning: .follicular)
                        case 15...18: cont.resume(returning: .ovulatory)
                        default: cont.resume(returning: .luteal)
                        }
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            }
            self.store.execute(query)
        }
    }
}

@MainActor
@Observable
final class HealthManager {

    // MARK: - HealthStore abstraction is defined at top-level (see HealthStore and LiveHealthStore)

    // MARK: - Init
    init(store: HealthStore) {
        self.store = store
        self.queryClient = HealthQueryClient(store: store)
    }

    convenience init() {
        self.init(store: LiveHealthStore())
    }

    // MARK: - Public state
    private let store: HealthStore
    private let queryClient: HealthQueryClient

    private(set) var isAuthorized = false
    private(set) var lastError: Error?

    /// The most recently fetched HealthData snapshot (cached for UI).
    private(set) var latestData: HealthData?

    // MARK: - Types we care about

    // Quantity types
    private var qtWater: HKQuantityType { .quantityType(forIdentifier: .dietaryWater)! }
    private var qtCaffeine: HKQuantityType { .quantityType(forIdentifier: .dietaryCaffeine)! }
    private var qtEnergy: HKQuantityType { .quantityType(forIdentifier: .dietaryEnergyConsumed)! }
    private var qtSteps: HKQuantityType { .quantityType(forIdentifier: .stepCount)! }
    private var qtRestingHR: HKQuantityType { .quantityType(forIdentifier: .restingHeartRate)! }
    private var qtHR: HKQuantityType { .quantityType(forIdentifier: .heartRate)! }
    private var qtGlucose: HKQuantityType { .quantityType(forIdentifier: .bloodGlucose)! }
    private var qtBloodOxygen: HKQuantityType { .quantityType(forIdentifier: .oxygenSaturation)! }

    // Category types
    private var ctSleep: HKCategoryType { .categoryType(forIdentifier: .sleepAnalysis)! }
    private var ctHeadache: HKCategoryType { .categoryType(forIdentifier: .headache)! }

    // Cycle tracking (optional)
    private var ctMenstrualFlow: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .menstrualFlow) }
    private var ctOvulation: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .ovulationTestResult) }

    // MARK: - Units we’ll use
    private let unitLiter = HKUnit.literUnit(with: .milli)       // mL
    private let unitMg = HKUnit.gramUnit(with: .milli)           // mg
    private let unitKCal = HKUnit.kilocalorie()
    private let unitCount = HKUnit.count()
    private let unitBPM = HKUnit.count().unitDivided(by: HKUnit.minute())
    private let unitMgPerdL = HKUnit(from: "mg/dL")              // Blood glucose common unit
    private let unitPercent = HKUnit.percent()                    // SpO2 in percent (0–100)

    // MARK: - Authorization
    
    func requestAuthorization() async {
        guard type(of: store).isHealthDataAvailable() else {
            let err = HealthError.healthDataUnavailable
            self.lastError = err
            self.isAuthorized = false
            print("[Health] Health data unavailable on this device: \(err)")
            return
        }

        var toRead: Set<HKObjectType> = [
            qtWater, qtCaffeine, qtEnergy, qtSteps, qtRestingHR, qtHR, ctSleep, qtGlucose, qtBloodOxygen, ctHeadache
        ]
        if let m = ctMenstrualFlow { toRead.insert(m) }
        if let o = ctOvulation { toRead.insert(o) }

        let toShare: Set<HKSampleType> = [
            qtWater, qtCaffeine, qtEnergy, ctSleep, ctHeadache
        ]

        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            // After request, inspect per-type status to decide "isAuthorized"
            await updateAuthorizationFlag(readTypes: toRead, shareTypes: toShare)
            self.lastError = nil
        } catch {
            self.isAuthorized = false
            self.lastError = HealthError.authorizationFailed(underlying: error)
            print("[Health] requestAuthorization failed: \(error)")
        }
    }

    private func updateAuthorizationFlag(readTypes: Set<HKObjectType>, shareTypes: Set<HKSampleType>) async {
        // Log request status (optional)
        do {
            let readReqStatus = try await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
            switch readReqStatus {
            case .unknown: print("[Health] Read request status: UNKNOWN")
            case .unnecessary: print("[Health] Read request status: UNNECESSARY")
            case .shouldRequest: print("[Health] Read request status: SHOULD REQUEST")
            @unknown default: print("[Health] Read request status: UNKNOWN(default)")
            }
        } catch {
            print("[Health] Failed to get overall read request status: \(error)")
            self.lastError = HealthError.readRequestStatusFailed(underlying: error)
        }

        if !shareTypes.isEmpty {
            do {
                let shareReqStatus = try await store.statusForAuthorizationRequest(toShare: shareTypes, read: [])
                switch shareReqStatus {
                case .unknown: print("[Health] Share request status: UNKNOWN")
                case .unnecessary: print("[Health] Share request status: UNNECESSARY")
                case .shouldRequest: print("[Health] Share request status: SHOULD REQUEST")
                @unknown default: print("[Health] Share request status: UNKNOWN(default)")
                }
            } catch {
                print("[Health] Failed to get share request status: \(error)")
                self.lastError = HealthError.shareRequestStatusFailed(underlying: error)
            }
        }

        // Determine actual authorization by checking per-type authorizationStatus(for:)
        var readOK = true
        for obj in readTypes {
            if let sampleType = obj as? HKSampleType {
                let status = store.authorizationStatus(for: sampleType)
                if status == .notDetermined {
                    readOK = false
                    print("[Health] Read authorization NOT DETERMINED for \(obj.identifier)")
                }
            }
        }

        var shareOK = true
        for sample in shareTypes {
            let status = store.authorizationStatus(for: sample)
            if status != .sharingAuthorized {
                shareOK = false
                print("[Health] Share authorization NOT AUTHORIZED for \(sample.identifier) (status=\(status.rawValue))")
            }
        }

        // Use readOK to set the overall flag (and log shareOK to avoid unused variable warnings).
        // If you want to require share authorization too, replace `readOK` with `(readOK && shareOK)`.
        self.isAuthorized = readOK
        print("[Health] Overall authorization flag (based on read): \(self.isAuthorized). Share authorized: \(shareOK)")
    }
    
    private func ensureAuthorized() async throws {
        if !isAuthorized {
            await requestAuthorization()
            if !isAuthorized {
                print("HEALTH NOT AUTHORIZED (isAuthorized=false). lastError=\(lastError?.localizedDescription ?? "nil")")
                throw HealthError.authorizationDenied
            }
        }
    }

    // MARK: - High-level snapshot API

    /// Fetch a single `HealthData` snapshot by aggregating samples within the window.
    func fetchSnapshot(
        from start: Date,
        to end: Date
    ) async throws -> HealthData {
        try await ensureAuthorized()

        async let waterML = queryClient.sumQuantity(qtWater, unit: unitLiter, from: start, to: end)
        async let caffeineMg = queryClient.sumQuantity(qtCaffeine, unit: unitMg, from: start, to: end)
        async let kcal = queryClient.sumQuantity(qtEnergy, unit: unitKCal, from: start, to: end)
        async let stepsRaw = queryClient.sumQuantity(qtSteps, unit: unitCount, from: start, to: end)
        async let restHRAvgRaw = queryClient.averageQuantity(qtRestingHR, unit: unitBPM, from: start, to: end)
        async let activeHRAvgRaw = queryClient.averageQuantity(qtHR, unit: unitBPM, from: start, to: end)
        async let glucoseAvg = queryClient.averageQuantity(qtGlucose, unit: unitMgPerdL, from: start, to: end)
        async let spo2Avg = queryClient.averageQuantity(qtBloodOxygen, unit: unitPercent, from: start, to: end)
        async let sleepHours = queryClient.totalSleepHours(ctSleep: ctSleep, from: start, to: end)
        async let phase = queryClient.inferMenstrualPhase(ctMenstrualFlow: ctMenstrualFlow, from: start, to: end)

        let steps = Int(try await stepsRaw)
        let restHRAvg = Int((try await restHRAvgRaw).rounded())
        let activeHRAvg = Int((try await activeHRAvgRaw).rounded())
        let glucose = try await glucoseAvg
        let spo2 = try await spo2Avg

        let snapshot = HealthData(
            waterLiters: try await (waterML / 1000.0),         // mL → L
            sleepHours: try await sleepHours,
            energyKilocalories: try await kcal,
            caffeineMg: try await caffeineMg,
            stepCount: steps,
            restingHeartRate: restHRAvg,
            activeHeartRate: activeHRAvg,
            glucoseMgPerdL: glucose > 0 ? glucose : nil,
            bloodOxygenPercent: spo2 > 0 ? spo2 : nil,
            menstrualPhase: try await phase,
            migraine: nil,
            createdAt: Date()
        )

        return snapshot
    }

    // MARK: - Latest snapshot convenience

    /// Convenience: refresh the latest snapshot for a migraine window.
    /// Fetches for the calendar day of `start` (midnight to start-of-next-day), or up to now if `start` is today.
    func refreshLatestForMigraine(start: Date, end: Date?) async {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: start)
        let dayEndExclusive = cal.date(byAdding: .day, value: 1, to: dayStart) ?? start
        let now = Date()
        // If the chosen start date is today, cap at now; otherwise use the full day.
        let effectiveEnd = cal.isDateInToday(start) ? min(now, dayEndExclusive) : dayEndExclusive
        await refreshLatest(from: dayStart, to: effectiveEnd)
    }

    /// Populate and cache the latest health snapshot for a given date range.
    /// Assigns `latestData` on success and sets `lastError` on failure.
    func refreshLatest(from start: Date, to end: Date) async {
        do {
            let snapshot = try await fetchSnapshot(from: start, to: end)
            self.latestData = snapshot
            self.lastError = nil
        } catch {
            print("Refresh of Health Data failed! error=\(error)")
            self.latestData = nil
            self.lastError = HealthError.snapshotFailed(underlying: error)
        }
    }

    /// Convenience: refresh the latest snapshot for "today" (midnight to now) in the current calendar/time zone.
    func refreshLatestForToday(calendar: Calendar = .current) async {
        print("Fetching today's health snapshot")
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        await refreshLatest(from: startOfDay, to: now)
    }

    /// Fetch a `HealthData` snapshot for a migraine window (without caching to `latestData`).
    /// Returns a snapshot for the selected start date’s calendar day (midnight to next midnight), or up to now if today.
    func fetchSnapshotForMigraine(start: Date, end: Date?) async throws -> HealthData {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: start)
        let dayEndExclusive = cal.date(byAdding: .day, value: 1, to: dayStart) ?? start
        let now = Date()
        let effectiveEnd = cal.isDateInToday(start) ? min(now, dayEndExclusive) : dayEndExclusive
        return try await fetchSnapshot(from: dayStart, to: effectiveEnd)
    }

    // MARK: - Writes

    func saveWater(liters: Double, date: Date = Date()) async throws {
        try await ensureAuthorized()
        let qty = HKQuantity(unit: unitLiter, doubleValue: liters * 1000.0) // L → mL
        let sample = HKQuantitySample(type: qtWater, quantity: qty, start: date, end: date)
        try await store.save(sample)
    }

    /// Convenience alias: label `on` forwards to `date:` for readability at call sites
    func saveWater(liters: Double, on date: Date) async throws {
        try await saveWater(liters: liters, date: date)
    }

    func saveCaffeine(mg: Double, date: Date = Date()) async throws {
        try await ensureAuthorized()
        let qty = HKQuantity(unit: unitMg, doubleValue: mg)
        let sample = HKQuantitySample(type: qtCaffeine, quantity: qty, start: date, end: date)
        try await store.save(sample)
    }

    /// Convenience alias: label `on` forwards to `date:` for readability at call sites
    func saveCaffeine(mg: Double, on date: Date) async throws {
        try await saveCaffeine(mg: mg, date: date)
    }

    func saveEnergy(kcal: Double, date: Date = Date()) async throws {
        try await ensureAuthorized()
        let qty = HKQuantity(unit: unitKCal, doubleValue: kcal)
        let sample = HKQuantitySample(type: qtEnergy, quantity: qty, start: date, end: date)
        try await store.save(sample)
    }

    /// Convenience alias: label `on` forwards to `date:` for readability at call sites
    func saveEnergy(kcal: Double, on date: Date) async throws {
        try await saveEnergy(kcal: kcal, date: date)
    }

    /// Save a simple sleep interval (asleep-unspecified).
    func saveSleep(from start: Date, to end: Date) async throws {
        try await ensureAuthorized()
        let sample = HKCategorySample(
            type: ctSleep,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: start,
            end: end
        )
        try await store.save(sample)
    }

    // MARK: - Headache (migraine) writes

    /// Map our app's Severity to HealthKit headache category values.
    private func hkHeadacheValue(from severity: Severity) -> HKCategoryValueSeverity {
        switch severity {
        case .low: return .mild
        case .medium: return .moderate
        case .high: return .severe
        }
    }

    /// Save a completed headache to HealthKit.
    /// - Note: HealthKit requires both start and end; do not call this for ongoing headaches.
    func saveHeadache(start: Date, end: Date, severity: Severity) async throws {
        try await ensureAuthorized()
        let value = hkHeadacheValue(from: severity).rawValue
        let sample = HKCategorySample(type: ctHeadache, value: value, start: start, end: end)
        try await store.save(sample)
    }

    /// Convenience: translate a Migraine to a HealthKit headache entry and save it if completed.
    func saveHeadacheForMigraine(_ migraine: Migraine) async {
        guard let end = migraine.endDate else { return } // only save when completed
        do {
            try await saveHeadache(start: migraine.startDate, end: end, severity: migraine.severity)
        } catch {
            print("[Health] Failed to save headache for migraine \(migraine.id): \(error)")
            self.lastError = HealthError.saveFailed(kind: "headache", underlying: error)
        }
    }
}

