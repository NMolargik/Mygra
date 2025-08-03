//
//  HealthKitUtility.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import HealthKit
import SwiftData
import Foundation

@MainActor
class HealthKitManager {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.dietaryWater),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.dietaryCaffeine),
            HKCategoryType(.menstrualFlow),
            HKQuantityType(.environmentalAudioExposure)
        ]
        let writeTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryWater),
            HKQuantityType(.dietaryEnergyConsumed),
            HKCategoryType(.sleepAnalysis)
        ]
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func fetchHealthData(for date: Date) async throws -> Migraine {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        async let water = fetchWater(dayStart: dayStart, dayEnd: dayEnd)
        async let sleep = fetchSleep(dayStart: dayStart, dayEnd: dayEnd)
        async let calories = fetchCalories(dayStart: dayStart, dayEnd: dayEnd)
        async let heartRate = fetchRestingHeartRate(dayStart: dayStart, dayEnd: dayEnd)
        async let hrv = fetchHRV(dayStart: dayStart, dayEnd: dayEnd)
        async let steps = fetchSteps(dayStart: dayStart, dayEnd: dayEnd)
        async let energy = fetchActiveEnergy(dayStart: dayStart, dayEnd: dayEnd)
        async let caffeine = fetchCaffeine(dayStart: dayStart, dayEnd: dayEnd)
        async let menstrual = fetchMenstrualPhase(dayStart: dayStart, dayEnd: dayEnd)
        async let noise = fetchNoise(dayStart: dayStart, dayEnd: dayEnd)

        return Migraine(
            timestamp: date,
            waterConsumed: try await water,
            sleepHours: try await sleep,
            caloriesConsumed: try await calories,
            restingHeartRate: try await heartRate,
            heartRateVariability: try await hrv,
            environmentalNoise: try await noise, stepCount: try await steps,
            activeEnergy: try await energy,
            caffeineIntake: try await caffeine,
            menstrualPhase: try await menstrual
        )
    }

    private func fetchWater(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let waterType = HKQuantityType(.dietaryWater)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: .liter())
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleep(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                let sleepHours = samples?.compactMap { sample -> Double? in
                    guard let categorySample = sample as? HKCategorySample,
                          categorySample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                          categorySample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                          categorySample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                          categorySample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue else {
                        return nil
                    }
                    return categorySample.endDate.timeIntervalSince(categorySample.startDate) / 3600.0
                }.reduce(0, +)
                continuation.resume(returning: sleepHours)
            }
            healthStore.execute(query)
        }
    }

    private func fetchCalories(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let calorieType = HKQuantityType(.dietaryEnergyConsumed)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchRestingHeartRate(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let heartRateType = HKQuantityType(.restingHeartRate)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchHRV(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: HKUnit.second()) / 1000.0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSteps(dayStart: Date, dayEnd: Date) async throws -> Int? {
        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: Int(value ?? 0))
            }
            healthStore.execute(query)
        }
    }

    private func fetchActiveEnergy(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchCaffeine(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let caffeineType = HKQuantityType(.dietaryCaffeine)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: caffeineType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: HKUnit.gramUnit(with: .milli))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchMenstrualPhase(dayStart: Date, dayEnd: Date) async throws -> Migraine.MenstrualPhase? {
        let menstrualType = HKCategoryType(.menstrualFlow)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: menstrualType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKCategorySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let phase: Migraine.MenstrualPhase?
                switch sample.value {
                case HKCategoryValueVaginalBleeding.light.rawValue:
                    phase = .menstruation
                case HKCategoryValueVaginalBleeding.medium.rawValue:
                    phase = .menstruation
                case HKCategoryValueVaginalBleeding.heavy.rawValue:
                    phase = .menstruation
                default:
                    phase = Migraine.MenstrualPhase.none
                }
                continuation.resume(returning: phase)
            }
            healthStore.execute(query)
        }
    }

    private func fetchNoise(dayStart: Date, dayEnd: Date) async throws -> Double? {
        let noiseType = HKQuantityType(.environmentalAudioExposure)
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: noiseType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = result?.averageQuantity()?.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // Write functions

    func saveWater(amount: Double, date: Date) async throws {
        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .liter(), doubleValue: amount)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        try await healthStore.save(sample)
    }

    func saveCalories(amount: Double, date: Date) async throws {
        let calorieType = HKQuantityType(.dietaryEnergyConsumed)
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: amount)
        let sample = HKQuantitySample(type: calorieType, quantity: quantity, start: date, end: date)
        try await healthStore.save(sample)
    }

    func saveSleep(startDate: Date, endDate: Date) async throws {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let sample = HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: startDate, end: endDate)
        try await healthStore.save(sample)
    }
}

