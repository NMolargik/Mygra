//
//  WeatherData.swift
//  MygraCore
//
//  Persisted snapshot of ambient weather, attached to a Migraine entry. Stored in SI
//  units; display helpers convert for the user's unit preference.
//

import Foundation
import SwiftData

@Model
public final class WeatherData {
    // MARK: - Core readings (SI)
    /// Barometric pressure in hectopascals (hPa). (1 hPa == 1 mbar)
    public var barometricPressureHpa: Double = 0.0
    /// Air temperature in degrees Celsius.
    public var temperatureCelsius: Double = 0.0
    /// Relative humidity in percent (0–100).
    public var humidityPercent: Double = 0.0
    /// High-level condition bucket for UI and analysis.
    public var condition: SkyCondition = SkyCondition.clear

    // MARK: - Metadata
    public var createdAt: Date = Date()
    /// Human-readable location at the time of capture (e.g., "Seattle, WA").
    public var locationDescription: String?

    // MARK: - Relationships
    public var migraine: Migraine?

    // MARK: - Init
    public init(
        barometricPressureHpa: Double = 0.0,
        temperatureCelsius: Double = 0.0,
        humidityPercent: Double = 0.0,
        condition: SkyCondition = .clear,
        createdAt: Date = Date(),
        locationDescription: String? = nil
    ) {
        self.barometricPressureHpa = barometricPressureHpa
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = humidityPercent
        self.condition = condition
        self.createdAt = createdAt
        self.locationDescription = locationDescription
    }

    // MARK: - Derived units

    public var temperatureFahrenheit: Double {
        get { UnitConversion.celsiusToFahrenheit(temperatureCelsius) }
        set { temperatureCelsius = UnitConversion.fahrenheitToCelsius(newValue) }
    }

    /// Barometric pressure in inches of mercury (inHg), derived from hPa.
    public var barometricPressureInHg: Double {
        get { barometricPressureHpa * UnitConversion.hectopascalsToInchesOfMercury }
        set { barometricPressureHpa = newValue / UnitConversion.hectopascalsToInchesOfMercury }
    }

    /// Temperature for a unit preference: Celsius (metric) or Fahrenheit.
    public func displayTemperature(useMetricUnits: Bool) -> Double {
        useMetricUnits ? temperatureCelsius : temperatureFahrenheit
    }

    /// Pressure for a unit preference: hPa (metric) or inHg.
    public func displayBarometricPressure(useMetricUnits: Bool) -> Double {
        useMetricUnits ? barometricPressureHpa : barometricPressureInHg
    }
}
