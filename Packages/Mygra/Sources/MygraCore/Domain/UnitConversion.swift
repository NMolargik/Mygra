//
//  UnitConversion.swift
//  MygraCore
//
//  Centralized unit-conversion constants and helpers.
//

import Foundation

nonisolated public enum UnitConversion {
    /// Liters to US fluid ounces (1 L = 33.814 fl oz).
    public static let litersToFluidOunces: Double = 33.814
    /// Kilocalories to kilojoules (1 kcal = 4.184 kJ).
    public static let kilocaloriesToKilojoules: Double = 4.184
    /// mg/dL to mmol/L for glucose (divide mg/dL by 18.0).
    public static let glucoseMgDlToMmolL: Double = 18.0
    /// Hectopascals to inches of mercury.
    public static let hectopascalsToInchesOfMercury: Double = 0.0295299830714
    /// Meters to inches.
    public static let metersToInches: Double = 39.37007874
    /// Kilograms to pounds.
    public static let kilogramsToPounds: Double = 2.2046226218
    /// Approximate caffeine per cup of coffee, in milligrams.
    public static let caffeineMgPerCup: Double = 95

    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        (celsius * 9.0 / 5.0) + 32.0
    }

    public static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        (fahrenheit - 32.0) * 5.0 / 9.0
    }

    /// Rounds `value` to the nearest `step` and clamps it into `range`.
    public static func snap(_ value: Double, toStep step: Double, in range: ClosedRange<Double>) -> Double {
        guard step > 0 else { return min(max(value, range.lowerBound), range.upperBound) }
        let snapped = (value / step).rounded() * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}
