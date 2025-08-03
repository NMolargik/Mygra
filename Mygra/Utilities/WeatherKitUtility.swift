//
//  WeatherKitUtility.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import WeatherKit
import CoreLocation
import SwiftData

class WeatherManager {
    private let weatherService = WeatherService.shared

    func fetchWeather(for date: Date, location: CLLocation) async throws -> (pressure: Double, temperature: Double, humidity: Double) {
        // Try to fetch the hourly forecast
        let hourlyForecast = try await weatherService.weather(for: location, including: .hourly)
        
        // Find the forecast hour closest to the specified date
        let closestHour = hourlyForecast.forecast.first { forecast in
            let timeDiff = abs(forecast.date.timeIntervalSince(date))
            return timeDiff < 60 * 60 // within 1 hour
        } ?? hourlyForecast.forecast.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        
        if let hour = closestHour {
            let pressure = hour.pressure.value // hPa
            let temperature = hour.temperature.value // Celsius
            let humidity = hour.humidity * 100 // Convert to percentage
            return (pressure, temperature, humidity)
        }

        // Fallback: fetch the current weather
        let currentWeather = try await weatherService.weather(for: location, including: .current)
        let pressure = currentWeather.pressure.value
        let temperature = currentWeather.temperature.value
        let humidity = currentWeather.humidity * 100
        return (pressure, temperature, humidity)
    }
}

// Example: Populate Migraine model
@MainActor
func logMigraine(context: ModelContext, user: User, timestamp: Date, location: CLLocation) async throws {
    let weatherData = try await WeatherManager().fetchWeather(for: timestamp, location: location)
    let migraine = Migraine(
        timestamp: timestamp,
        barometricPressure: weatherData.pressure,
        temperature: weatherData.temperature,
        humidity: weatherData.humidity,
        user: user
        // Other fields from HealthKit/user input
    )
    context.insert(migraine)
}

