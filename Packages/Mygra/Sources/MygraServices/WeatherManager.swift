//
//  WeatherManager.swift
//  MygraServices
//
//  WeatherKit current conditions, throttled (global 1-hour cooldown on successful
//  fetches; 10-minute / 500 m gating when streaming), with reverse geocoding for a
//  location label. Exposes readings as the Core value type `WeatherReading` so
//  features never import WeatherKit.
//

import Foundation
import CoreLocation
import Observation
import WeatherKit
import MygraCore
import os

nonisolated public enum WeatherError: LocalizedError, Equatable {
    case locationProviderMissing
    case locationUnavailable
    case weatherServiceFailed
    case geocodingFailed
    case cooldown(nextEligible: Date)

    public var errorDescription: String? {
        switch self {
        case .locationProviderMissing: return String(localized: "No location provider has been set.")
        case .locationUnavailable: return String(localized: "Unable to get current location.")
        case .weatherServiceFailed: return String(localized: "Failed to fetch weather data.")
        case .geocodingFailed: return String(localized: "Failed to resolve location name.")
        case .cooldown(let next):
            return String(localized: "You can refresh weather again at \(DateFormatting.time(next)).")
        }
    }
}

/// A Core-typed snapshot of the latest current conditions.
nonisolated public struct WeatherReading: Equatable, Sendable {
    public var temperature: Measurement<UnitTemperature>
    public var pressure: Measurement<UnitPressure>
    /// 0.0 ... 1.0
    public var humidity: Double
    public var condition: SkyCondition
    public var fetchedAt: Date

    public init(temperature: Measurement<UnitTemperature>, pressure: Measurement<UnitPressure>, humidity: Double, condition: SkyCondition, fetchedAt: Date) {
        self.temperature = temperature
        self.pressure = pressure
        self.humidity = humidity
        self.condition = condition
        self.fetchedAt = fetchedAt
    }

    public var pressureHpa: Double { pressure.converted(to: .hectopascals).value }
    public var temperatureCelsius: Double { temperature.converted(to: .celsius).value }
    public var humidityPercent: Double { humidity * 100 }

    /// Formats the temperature for the user's unit preference, e.g. "78°".
    public func formattedTemperature(useMetricUnits: Bool) -> String {
        let converted = temperature.converted(to: useMetricUnits ? .celsius : .fahrenheit)
        return "\(Int(converted.value.rounded()))°"
    }

    /// Formats the pressure for the user's unit preference, e.g. "1013 hPa" or "29.92 inHg".
    public func formattedPressure(useMetricUnits: Bool) -> String {
        if useMetricUnits {
            return "\(Int(pressureHpa.rounded())) hPa"
        }
        return String(format: "%.2f inHg", pressure.converted(to: .inchesOfMercury).value)
    }

    /// e.g. "57%".
    public var formattedHumidity: String {
        humidity.formatted(.percent.precision(.fractionLength(0)))
    }

    /// The persisted snapshot for a migraine that started at `date`.
    public func makeWeatherData(createdAt date: Date, locationDescription: String?) -> WeatherData {
        WeatherData(
            barometricPressureHpa: pressureHpa,
            temperatureCelsius: temperatureCelsius,
            humidityPercent: humidityPercent,
            condition: condition,
            createdAt: date,
            locationDescription: locationDescription
        )
    }
}

extension SkyCondition {
    /// Maps WeatherKit's condition onto the persisted bucket (raw values line up one-to-one).
    public init(_ condition: WeatherCondition) {
        self = SkyCondition(rawValue: condition.rawValue) ?? .cloudy
    }
}

@MainActor
@Observable
public final class WeatherManager: CurrentWeatherProviding {

    // MARK: - Dependencies
    @ObservationIgnored private let service: WeatherService
    public private(set) var locationManager: LocationManager?

    // MARK: - State
    public private(set) var isFetching = false
    public private(set) var reading: WeatherReading?
    public private(set) var placemark: CLPlacemark?
    public var error: (any Error)?

    @ObservationIgnored private var lastLocation: CLLocation?
    @ObservationIgnored private var lastSuccessfulFetch: Date?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let geocoder = CLGeocoder()

    // MARK: - Throttling knobs
    /// Minimum time between successive successful updates when streaming.
    public var minUpdateInterval: TimeInterval = 10 * 60
    /// Minimum distance change required to fetch again when streaming.
    public var minDistanceChange: CLLocationDistance = 500
    /// Global cooldown between successful WeatherKit hits (cost control).
    public var refreshCooldownInterval: TimeInterval = 60 * 60

    public init(service: WeatherService = .shared, locationManager: LocationManager? = nil) {
        self.service = service
        self.locationManager = locationManager
    }

    // MARK: - Wiring

    public func setLocationProvider(_ manager: LocationManager?) {
        locationManager = manager
    }

    /// Follows a provider's continuous updates (throttled by time + distance).
    public func setUpdatesProvider(_ provider: LocationManager?) {
        updatesTask?.cancel()
        locationManager = provider
        guard let provider else { return }
        updatesTask = Task { [weak self] in
            for await location in provider.locationUpdates() {
                guard let self, !Task.isCancelled else { return }
                do { try await self.fetch(for: location) } catch { self.error = error }
            }
        }
    }

    // MARK: - Derived

    public var lastUpdated: Date? { reading?.fetchedAt }
    public var hasReading: Bool { reading != nil }

    /// The readings that feed `WeatherRisk`.
    public var riskInput: WeatherRiskInput {
        WeatherRiskInput(humidity: reading?.humidity, pressureHpa: reading?.pressureHpa, condition: reading?.condition)
    }

    /// Human-readable location name, e.g. "Seattle, WA" or "Seattle, US".
    public var locationString: String? {
        guard let placemark else { return nil }
        if let city = placemark.locality, let admin = placemark.administrativeArea, !admin.isEmpty {
            return "\(city), \(admin)"
        }
        if let city = placemark.locality, let country = placemark.isoCountryCode {
            return "\(city), \(country)"
        }
        return placemark.locality ?? placemark.name
    }

    /// The persisted snapshot for a migraine that started at `date`, or nil without a reading.
    public func makeWeatherData(createdAt date: Date) -> WeatherData? {
        reading?.makeWeatherData(createdAt: date, locationDescription: locationString)
    }

    // MARK: - Refresh

    /// One-off refresh using the provider's current location. Surfaces the cooldown as
    /// a transient error so the UI can explain why nothing changed.
    public func refresh() async {
        if let next = cooldownEnd, Date() < next {
            setTransientError(WeatherError.cooldown(nextEligible: next), duration: 3.0)
            Log.weather.info("Too soon to refresh weather. Next eligible: \(next)")
            return
        }
        guard let provider = locationManager else {
            Log.weather.error("No location provider for WeatherManager")
            error = WeatherError.locationProviderMissing
            return
        }
        let location: CLLocation
        do {
            location = try await provider.currentLocation()
        } catch {
            self.error = WeatherError.locationUnavailable
            return
        }
        do {
            try await fetch(for: location)
            Log.weather.debug("Refreshed weather")
        } catch {
            self.error = (error as? WeatherError) ?? WeatherError.weatherServiceFailed
            Log.weather.error("Failed to refresh: \(error.localizedDescription)")
        }
    }

    /// Core fetch for a specific location (cooldown- and distance-gated).
    public func fetch(for location: CLLocation) async throws {
        if let next = cooldownEnd, Date() < next { return }
        if let last = lastLocation, let lastTime = lastUpdated {
            let farEnough = location.distance(from: last) >= minDistanceChange
            let oldEnough = Date().timeIntervalSince(lastTime) >= minUpdateInterval
            if !farEnough && !oldEnough { return }
        }

        isFetching = true
        error = nil
        defer { isFetching = false }

        let now = Date()
        let current = try await service.weather(for: location, including: .current)
        reading = WeatherReading(
            temperature: current.temperature,
            pressure: current.pressure,
            humidity: current.humidity,
            condition: SkyCondition(current.condition),
            fetchedAt: now
        )
        lastSuccessfulFetch = now

        await reverseGeocodeIfNeeded(for: location)
        lastLocation = location
    }

    // MARK: - Private

    private var cooldownEnd: Date? {
        lastSuccessfulFetch?.addingTimeInterval(refreshCooldownInterval)
    }

    private func setTransientError(_ error: any Error, duration: TimeInterval) {
        self.error = error
        let description = error.localizedDescription
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, self.error?.localizedDescription == description else { return }
            self.error = nil
        }
    }

    private func reverseGeocodeIfNeeded(for location: CLLocation) async {
        if placemark != nil, let last = lastLocation, location.distance(from: last) < 100 { return }
        geocoder.cancelGeocode()
        do {
            placemark = try await geocoder.reverseGeocodeLocation(location).first
        } catch {
            // Non-fatal; we simply won't show a location string.
            Log.weather.debug("Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
}
