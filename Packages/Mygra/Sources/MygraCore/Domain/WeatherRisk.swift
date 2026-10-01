//
//  WeatherRisk.swift
//  MygraCore
//
//  Pure migraine-risk evaluation over current weather conditions, plus the policy that
//  decides when a rising risk deserves a notification.
//

import Foundation

/// A value snapshot of the readings that feed risk evaluation.
nonisolated public struct WeatherRiskInput: Sendable, Equatable {
    /// Relative humidity 0.0...1.0.
    public var humidity: Double?
    /// Barometric pressure in hectopascals.
    public var pressureHpa: Double?
    public var condition: SkyCondition?

    public init(humidity: Double?, pressureHpa: Double?, condition: SkyCondition?) {
        self.humidity = humidity
        self.pressureHpa = pressureHpa
        self.condition = condition
    }
}

nonisolated public enum WeatherRisk {
    /// Humidity at or above this fraction is considered high risk.
    public static let humidityThreshold = 0.70
    /// Pressure below this (hPa) is considered high risk.
    public static let lowPressureThresholdHpa = 1008.0

    public static func isHighRisk(_ input: WeatherRiskInput) -> Bool {
        let humidityHigh = input.humidity.map { $0 >= humidityThreshold } ?? false
        let pressureLow = input.pressureHpa.map { $0 < lowPressureThresholdHpa } ?? false
        let storms = input.condition == .strongStorms
        return humidityHigh || pressureLow || storms
    }

    /// Whether a notification should fire: only on the transition into high risk.
    public static func shouldNotify(input: WeatherRiskInput, wasHighRisk: Bool) -> Bool {
        isHighRisk(input) && !wasHighRisk
    }

    /// User-facing notification content describing the current risk conditions.
    public static func notificationContent(_ input: WeatherRiskInput) -> (title: String, body: String) {
        var parts: [String] = []
        if let condition = input.condition {
            parts.append(condition.displayName)
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
