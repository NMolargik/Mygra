//
//  WeatherData.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation
import SwiftData
import WeatherKit

/// Persisted snapshot of ambient weather, attached to a Migraine entry.
/// Stored in SI units for consistency; UI can present Imperial via helpers.
@Model
final class WeatherData {
    // MARK: - Core readings (SI)
    /// Barometric pressure in hectopascals (hPa). (1 hPa == 1 mbar)
    var barometricPressureHpa: Double = 0.0

    /// Air temperature in degrees Celsius.
    var temperatureCelsius: Double = 0.0

    /// Relative humidity in percent (0–100).
    var humidityPercent: Double = 0.0

    /// High-level condition bucket for UI and analysis.
    var condition: WeatherCondition = WeatherCondition.clear

    // MARK: - Metadata
    var createdAt: Date = Date()

    /// Human-readable location at the time of capture (e.g., "Seattle, WA").
    /// Optional; may be nil if reverse geocoding was unavailable.
    var locationDescription: String?

    // MARK: - Relationships
    var migraine: Migraine?

    // MARK: - Init
    init(
        barometricPressureHpa: Double = 0.0,
        temperatureCelsius: Double = 0.0,
        humidityPercent: Double = 0.0,
        condition: WeatherCondition = WeatherCondition.clear,
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

    var temperatureFahrenheit: Double {
        get { (temperatureCelsius * 9.0/5.0) + 32.0 }
        set { temperatureCelsius = (newValue - 32.0) * 5.0/9.0; }
    }

    /// Barometric pressure in inches of mercury (inHg), derived from hPa.
    /// Conversion: 1 hPa = 0.0295299830714 inHg
    var barometricPressureInHg: Double {
        get { barometricPressureHpa * 0.0295299830714 }
        set { barometricPressureHpa = newValue / 0.0295299830714; }
    }

    /// Millibars are numerically equal to hPa; provided for clarity.
    var barometricPressureMillibars: Double {
        get { barometricPressureHpa }
        set { barometricPressureHpa = newValue; }
    }

    /// Returns the temperature value to display for a unit preference.
    /// - Parameter useMetricUnits: true → Celsius, false → Fahrenheit.
    func displayTemperature(useMetricUnits: Bool) -> Double {
        useMetricUnits ? temperatureCelsius : temperatureFahrenheit
    }

    /// Sets temperature from a UI value for a given unit preference.
    func setDisplayTemperature(_ value: Double, useMetricUnits: Bool) {
        if useMetricUnits { temperatureCelsius = value } else { temperatureFahrenheit = value }
    }

    /// Returns the barometric pressure value to display for a unit preference.
    /// - Parameter useMetricUnits: true → hPa, false → inHg.
    func displayBarometricPressure(useMetricUnits: Bool) -> Double {
        useMetricUnits ? barometricPressureHpa : barometricPressureInHg
    }

    /// Sets pressure from a UI value for a given unit preference.
    func setDisplayBarometricPressure(_ value: Double, useMetricUnits: Bool) {
        if useMetricUnits { barometricPressureHpa = value } else { barometricPressureInHg = value }
    }
}
