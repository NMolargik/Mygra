//
//  IntakeAdditions.swift
//  MygraCore
//
//  Staged intake the user wants written to Health (water, caffeine, food, sleep).
//  Shared by the dashboard Quick Add, the entry form, and the modify sheet — the three
//  places that used to keep four loose Doubles each.
//

import Foundation

nonisolated public struct IntakeAdditions: Equatable, Sendable {
    /// Liters (stored metric regardless of the display preference).
    public var waterLiters: Double = 0
    /// Milligrams.
    public var caffeineMg: Double = 0
    /// Kilocalories.
    public var foodKilocalories: Double = 0
    /// Hours.
    public var sleepHours: Double = 0

    public static let none = IntakeAdditions()

    public init(waterLiters: Double = 0, caffeineMg: Double = 0, foodKilocalories: Double = 0, sleepHours: Double = 0) {
        self.waterLiters = waterLiters
        self.caffeineMg = caffeineMg
        self.foodKilocalories = foodKilocalories
        self.sleepHours = sleepHours
    }

    /// True when nothing is staged.
    public var isEmpty: Bool {
        waterLiters <= 0 && caffeineMg <= 0 && foodKilocalories <= 0 && sleepHours <= 0
    }

    // MARK: - Slider geometry

    /// Water slider range in liters (both unit systems edit liters under the hood).
    public static let waterRangeLiters: ClosedRange<Double> = 0...2.5
    public static let caffeineRangeMg: ClosedRange<Double> = 0...1000
    public static let foodRangeKilocalories: ClosedRange<Double> = 0...2500
    public static let sleepRangeHours: ClosedRange<Double> = 0...12

    /// Water slider step: 0.1 L (metric) or 8 fl oz expressed in liters.
    public static func waterStep(useMetricUnits: Bool) -> Double {
        useMetricUnits ? 0.1 : 8.0 / UnitConversion.litersToFluidOunces
    }

    public static let caffeineStepMg: Double = 10
    public static let foodStepKilocalories: Double = 50
    public static let sleepStepHours: Double = 0.5

    /// Re-snaps the staged water to the step of the (new) unit preference.
    public mutating func snapWater(useMetricUnits: Bool) {
        waterLiters = UnitConversion.snap(waterLiters, toStep: Self.waterStep(useMetricUnits: useMetricUnits), in: Self.waterRangeLiters)
    }
}
