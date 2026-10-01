//
//  HealthData.swift
//  MygraCore
//
//  Snapshot of health metrics around the time of a migraine. Stored in SI units;
//  display conversions go through `UnitConversion`.
//

import Foundation
import SwiftData

@Model
public final class HealthData {
    // MARK: - Core metrics (SI units)
    /// Water consumed in liters.
    public var waterLiters: Double?
    /// Sleep duration in hours.
    public var sleepHours: Double?
    /// Energy consumed in kilocalories.
    public var energyKilocalories: Double?
    /// Caffeine consumed in milligrams.
    public var caffeineMg: Double?
    /// Step count.
    public var stepCount: Int?
    /// Resting heart rate in beats per minute.
    public var restingHeartRate: Int?
    /// Active heart rate in beats per minute.
    public var activeHeartRate: Int?
    /// Average blood glucose in mg/dL for the sampled window.
    public var glucoseMgPerdL: Double?
    /// Average blood oxygen saturation as a fraction (0.0–1.0) for the sampled window.
    public var bloodOxygenPercent: Double?
    /// Menstrual phase, if cycle tracking data was available.
    public var menstrualPhase: MenstrualPhase?

    /// Link back to Migraine (inverse relationship).
    public var migraine: Migraine?

    // MARK: - Metadata
    public var createdAt: Date = Date()

    // MARK: - Init
    public init(
        waterLiters: Double? = nil,
        sleepHours: Double? = nil,
        energyKilocalories: Double? = nil,
        caffeineMg: Double? = nil,
        stepCount: Int? = nil,
        restingHeartRate: Int? = nil,
        activeHeartRate: Int? = nil,
        glucoseMgPerdL: Double? = nil,
        bloodOxygenPercent: Double? = nil,
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
        self.glucoseMgPerdL = glucoseMgPerdL
        self.bloodOxygenPercent = bloodOxygenPercent
        self.menstrualPhase = menstrualPhase
        self.migraine = migraine
        self.createdAt = createdAt
    }

    // MARK: - Derived units

    /// Water in US fluid ounces (derived from liters).
    public var waterOunces: Double? {
        get { waterLiters.map { $0 * UnitConversion.litersToFluidOunces } }
        set { waterLiters = newValue.map { $0 / UnitConversion.litersToFluidOunces } }
    }

    /// Energy in kilojoules (derived from kcal).
    public var energyKilojoules: Double? {
        get { energyKilocalories.map { $0 * UnitConversion.kilocaloriesToKilojoules } }
        set { energyKilocalories = newValue.map { $0 / UnitConversion.kilocaloriesToKilojoules } }
    }

    /// Glucose in mmol/L (derived from mg/dL).
    public var glucoseMmolPerL: Double? {
        get { glucoseMgPerdL.map { $0 / UnitConversion.glucoseMgDlToMmolL } }
        set { glucoseMgPerdL = newValue.map { $0 * UnitConversion.glucoseMgDlToMmolL } }
    }

    /// Water intake for a unit preference: liters (metric) or fluid ounces.
    public func displayWater(useMetricUnits: Bool) -> Double? {
        useMetricUnits ? waterLiters : waterOunces
    }

    /// Which of the core intake metrics read as exactly zero for the window — a hint
    /// that nothing has been logged in Health yet.
    public var zeroIntakeMetrics: [String] {
        var items: [String] = []
        if sleepHours == 0 { items.append(String(localized: "sleep")) }
        if caffeineMg == 0 { items.append(String(localized: "caffeine")) }
        if waterLiters == 0 { items.append(String(localized: "water")) }
        if energyKilocalories == 0 { items.append(String(localized: "calories")) }
        return items
    }
}
