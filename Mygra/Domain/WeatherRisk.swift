//
//  WeatherRisk.swift
//  Mygra
//
//  Pure migraine-risk evaluation over current weather conditions.
//

import Foundation
import WeatherKit

/// A value snapshot of the readings that feed risk evaluation.
struct WeatherRiskInput: Sendable {
    /// Relative humidity 0.0...1.0.
    var humidity: Double?
    /// Barometric pressure in hectopascals.
    var pressureHpa: Double?
    var condition: WeatherCondition?
}

enum WeatherRisk {
    /// Humidity at or above this fraction is considered high risk.
    static let humidityThreshold = 0.70
    /// Pressure below this (hPa) is considered high risk.
    static let lowPressureThresholdHpa = 1008.0

    static func isHighRisk(_ input: WeatherRiskInput) -> Bool {
        let humidityHigh = input.humidity.map { $0 >= humidityThreshold } ?? false
        let pressureLow = input.pressureHpa.map { $0 < lowPressureThresholdHpa } ?? false
        let storms = input.condition == .strongStorms
        return humidityHigh || pressureLow || storms
    }

    /// User-facing notification content describing the current risk conditions.
    static func notificationContent(_ input: WeatherRiskInput) -> (title: String, body: String) {
        var parts: [String] = []
        if let condition = input.condition {
            parts.append(condition.description.capitalized)
        }
        if let pressure = input.pressureHpa {
            parts.append(String(format: "%.0f hPa", pressure))
        }
        if let humidity = input.humidity {
            parts.append(String(format: "%.0f%% humidity", humidity * 100.0))
        }
        let summary = parts.isEmpty ? String(localized: "Current conditions") : parts.joined(separator: " • ")
        return (
            title: String(localized: "Weather may trigger a migraine"),
            body: String(localized: "\(summary). Consider hydration, rest, and minimizing triggers.")
        )
    }
}
