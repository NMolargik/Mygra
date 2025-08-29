//
//  HealthManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import HealthKit
import Observation
import CoreLocation

@MainActor
@Observable
final class HealthManager {

    // MARK: - Public state
    private(set) var isAuthorized = false
    private(set) var lastError: Error?

    /// The most recently fetched HealthData snapshot (cached for UI).
    private(set) var latestData: HealthData?

    // MARK: - Private
    private let store = HKHealthStore()

    // MARK: - Types we care about

    // Quantity types
    private var qtWater: HKQuantityType { .quantityType(forIdentifier: .dietaryWater)! }
    private var qtCaffeine: HKQuantityType { .quantityType(forIdentifier: .dietaryCaffeine)! }
    private var qtEnergy: HKQuantityType { .quantityType(forIdentifier: .dietaryEnergyConsumed)! }
    private var qtSteps: HKQuantityType { .quantityType(forIdentifier: .stepCount)! }
    private var qtRestingHR: HKQuantityType { .quantityType(forIdentifier: .restingHeartRate)! }
    private var qtHR: HKQuantityType { .quantityType(forIdentifier: .heartRate)! }

    // Category types
    private var ctSleep: HKCategoryType { .categoryType(forIdentifier: .sleepAnalysis)! }

    // Cycle tracking (optional)
    private var ctMenstrualFlow: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .menstrualFlow) }
    private var ctOvulation: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .ovulationTestResult) }

    // MARK: - Units we’ll use
    private let unitLiter = HKUnit.literUnit(with: .milli)       // mL
    private let unitMg = HKUnit.gramUnit(with: .milli)           // mg
    private let unitKCal = HKUnit.kilocalorie()
    private let unitCount = HKUnit.count()
    private let unitBPM = HKUnit.count().unitDivided(by: HKUnit.minute())

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.lastError = HKError(.errorAuthorizationDenied)
            self.isAuthorized = false
            return
        }

        var toRead: Set<HKObjectType> = [
            qtWater, qtCaffeine, qtEnergy, qtSteps, qtRestingHR, qtHR, ctSleep
        ]
        if let m = ctMenstrualFlow { toRead.insert(m) }
        if let o = ctOvulation { toRead.insert(o) }

        let toShare: Set<HKSampleType> = [
            qtWater, qtCaffeine, qtEnergy, ctSleep
        ]

        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            self.isAuthorized = true
            self.lastError = nil
        } catch {
            self.isAuthorized = false
            self.lastError = error
        }
    }

    // MARK: - High-level snapshot API

    /// Fetch a single `HealthData` snapshot by aggregating samples within the window.
    func fetchSnapshot(
        from start: Date,
        to end: Date
    ) async throws -> HealthData {
        try await ensureAuthorized()

        async let waterML = sumQuantity(qtWater, unit: unitLiter, from: start, to: end)
        async let caffeineMg = sumQuantity(qtCaffeine, unit: unitMg, from: start, to: end)
        async let kcal = sumQuantity(qtEnergy, unit: unitKCal, from: start, to: end)
        async let stepsRaw = sumQuantity(qtSteps, unit: unitCount, from: start, to: end)
        async let restHRAvgRaw = averageQuantity(qtRestingHR, unit: unitBPM, from: start, to: end)
        async let activeHRAvgRaw = averageQuantity(qtHR, unit: unitBPM, from: start, to: end)
        async let sleepHours = totalSleepHours(from: start, to: end)
        async let phase = inferMenstrualPhase(from: start, to: end)

        let steps = Int(try await stepsRaw)
        let restHRAvg = Int((try await restHRAvgRaw).rounded())
        let activeHRAvg = Int((try await activeHRAvgRaw).rounded())

        let snapshot = HealthData(
            waterLiters: try await (waterML / 1000.0),         // mL → L
            sleepHours: try await sleepHours,
            energyKilocalories: try await kcal,
            caffeineMg: try await caffeineMg,
            stepCount: steps,
            restingHeartRate: restHRAvg,
            activeHeartRate: activeHRAvg,
            menstrualPhase: try await phase,
            migraine: nil
        )

        return snapshot
    }

    // MARK: - Latest snapshot convenience

    /// Populate and cache the latest health snapshot for a given date range.
    /// Assigns `latestData` on success and sets `lastError` on failure.
    func refreshLatest(from start: Date, to end: Date) async {
        do {
            let snapshot = try await fetchSnapshot(from: start, to: end)
            self.latestData = snapshot
            self.lastError = nil
        } catch {
            self.latestData = nil
            self.lastError = error
        }
    }

    /// Convenience: refresh the latest snapshot for "today" (midnight to now) in the current calendar/time zone.
    func refreshLatestForToday(calendar: Calendar = .current) async {
        print("Fetching today's health snapshot")
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        await refreshLatest(from: startOfDay, to: now)
    }

    // MARK: - Writes

    func saveWater(liters: Double, date: Date = Date()) async throws {
        try await ensureAuthorized()
        let qty = HKQuantity(unit: unitLiter, doubleValue: liters * 1000.0) // L → mL
        let sample = HKQuantitySample(type: qtWater, quantity: qty, start: date, end: date)
        try await store.save(sample)
    }

    func saveCaffeine(mg: Double, date: Date = Date()) async throws {
        try await ensureAuthorized()
        let qty = HKQuantity(unit: unitMg, doubleValue: mg)
        let sample = HKQuantitySample(type: qtCaffeine, quantity: qty, start: date, end: date)
        try await store.save(sample)
    }

    func saveEnergy(kcal: Double, date: Date = Date()) async throws {
        try await ensureAuthorized()
        let qty = HKQuantity(unit: unitKCal, doubleValue: kcal)
        let sample = HKQuantitySample(type: qtEnergy, quantity: qty, start: date, end: date)
        try await store.save(sample)
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

    // MARK: - Granular helpers (reads)

    func sumQuantity(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                let total = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: total)
            }
            store.execute(query)
        }
    }

    func averageQuantity(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                let avg = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: avg)
            }
            store.execute(query)
        }
    }

    private func totalSleepHours(from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: ctSleep, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { cont.resume(throwing: error); return }

                let totalSeconds = (samples as? [HKCategorySample])?
                    .filter { sample in
                        let v = HKCategoryValueSleepAnalysis(rawValue: sample.value) ?? .inBed
                        return v == .asleepUnspecified || v == .asleepCore || v == .asleepDeep || v == .asleepREM
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0.0

                cont.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }

    // MARK: - Menstrual phase (optional & naive)

    private func inferMenstrualPhase(from start: Date, to end: Date) async throws -> MenstrualPhase? {
        // If you don’t want this, return nil and remove the read types above.
        guard let flowType = ctMenstrualFlow else { return nil }

        return try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-28*24*3600), end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: flowType, predicate: predicate, limit: 50, sortDescriptors: [sort]) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let recent = (samples as? [HKCategorySample]) ?? []

                // Extremely rough heuristic: if there’s any recent "heavy" flow in the past 7 days → Menstruation
                let sevenDaysAgo = Date().addingTimeInterval(-7*24*3600)
                let hasRecentHeavy = recent.contains {
                    $0.endDate >= sevenDaysAgo &&
                    HKCategoryValueVaginalBleeding(rawValue: $0.value) == .heavy
                }

                if hasRecentHeavy {
                    cont.resume(returning: .menstrual)
                } else {
                    // Otherwise guess phases by days since last recorded flow (very naive).
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
            store.execute(query)
        }
    }

    // MARK: - Utils

    private func ensureAuthorized() async throws {
        if !isAuthorized {
            await requestAuthorization()
            if !isAuthorized {
                throw HKError(.errorAuthorizationDenied)
            }
        }
    }
}

