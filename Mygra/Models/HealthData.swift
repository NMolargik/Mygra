//
//  HealthData.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation
import SwiftData

/// Snapshot of health metrics around the time of a migraine.
/// Stored in SI units internally; UI helpers provide Imperial conversions.
@Model
final class HealthData {
    // MARK: - Core metrics (SI units)
    /// Water consumed in liters.
    var waterLiters: Double?

    /// Sleep duration in hours.
    var sleepHours: Double?

    /// Energy consumed in kilocalories.
    var energyKilocalories: Double?

    /// Caffeine consumed in milligrams.
    var caffeineMg: Double?

    /// Step count, optional.
    var stepCount: Int?

    /// Resting heart rate in beats per minute.
    var restingHeartRate: Int?

    /// Active heart rate in beats per minute.
    var activeHeartRate: Int?

    /// Menstrual phase, optional.
    var menstrualPhase: MenstrualPhase?

    /// Link back to Migraine (inverse relationship)
    var migraine: Migraine?

    // MARK: - Metadata
    var createdAt: Date = Date()

    // MARK: - Init
    init(
        waterLiters: Double? = nil,
        sleepHours: Double? = nil,
        energyKilocalories: Double? = nil,
        caffeineMg: Double? = nil,
        stepCount: Int? = nil,
        restingHeartRate: Int? = nil,
        activeHeartRate: Int? = nil,
        menstrualPhase: MenstrualPhase? = nil,
        migraine: Migraine? = nil,
        createdAt: Date = Date()
    ) {
        self.waterLiters = waterLiters
        self.sleepHours = sleepHours
        self.energyKilocalories = energyKilocalories
        self.caffeineMg = caffeineMg
        self.stepCount = stepCount
        self.restingHeartRate = restingHeartRate
        self.activeHeartRate = activeHeartRate
        self.menstrualPhase = menstrualPhase
        self.migraine = migraine
        self.createdAt = createdAt
    }

    /// Water in fluid ounces (derived from liters).
    var waterOunces: Double? {
        get { waterLiters.map { $0 * 33.814 } }
        set { waterLiters = newValue.map { $0 / 33.814 }; }
    }

    /// Energy in kilojoules (derived from kcal).
    var energyKilojoules: Double? {
        get { energyKilocalories.map { $0 * 4.184 } }
        set { energyKilocalories = newValue.map { $0 / 4.184 }; }
    }

    /// Returns water intake to display given unit preference.
    /// - Parameter useMetricUnits: true → liters, false → fluid ounces.
    func displayWater(useMetricUnits: Bool) -> Double? {
        useMetricUnits ? waterLiters : waterOunces
    }

    /// Returns energy intake to display given unit preference.
    /// - Parameter useMetricUnits: true → kcal, false → kcal (same)
    /// Note: we default to kcal for both systems, but provide kJ as helper.
    func displayEnergy(useMetricUnits: Bool) -> Double? {
        energyKilocalories
    }}

