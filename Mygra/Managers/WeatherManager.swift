//
//  WeatherManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import CoreLocation
import WeatherKit
import Observation

@MainActor
@Observable
final class WeatherManager {

    // MARK: - Dependencies
    private let service: WeatherService
    // Optional location manager provided by onboarding or elsewhere.
    private(set) var locationManager: LocationManager?

    // MARK: - State
    private(set) var isFetching = false
    private(set) var lastUpdated: Date?
    private(set) var error: Error?

    private(set) var temperature: Measurement<UnitTemperature>?
    private(set) var pressure: Measurement<UnitPressure>?
    /// 0.0 ... 1.0 (57% => 0.57)
    private(set) var humidity: Double?
    private(set) var condition: WeatherCondition?

    // Throttling knobs
    /// Minimum time between successive successful updates (used with distance gating when streaming)
    var minUpdateInterval: TimeInterval = 10 * 60 // 10 minutes
    /// Minimum distance change required to fetch again when streaming
    var minDistanceChange: CLLocationDistance = 500 // meters

    /// Global cooldown to avoid costly WeatherKit hits from any trigger (manual, initial load, streaming).
    /// If a request was made less than this interval ago, we skip new requests.
    var refreshCooldownInterval: TimeInterval = 5 * 60 // 5 minutes

    // Internal
    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?
    @ObservationIgnored
    private var lastLocation: CLLocation?
    @ObservationIgnored
    private var lastRequestAttempt: Date?

    // MARK: - Init / deinit
    init(service: WeatherService = .shared, locationManager: LocationManager? = nil) {
        self.service = service
        self.locationManager = locationManager
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Wiring

    func setLocationProvider(_ manager: LocationManager?) {
        self.locationManager = manager
    }

    /// Set a provider that emits continuous updates.
    /// Starts listening immediately.
    func setUpdatesProvider(_ provider: LocationManager?) {
        updatesTask?.cancel()
        self.locationManager = provider
        guard let provider else { return }
        startListening(to: provider)
    }

    // MARK: - Refresh

    /// One-off refresh using the current provider’s current location.
    func refresh() async {
        // Global cooldown gate
        if let lastAttempt = lastRequestAttempt,
           Date().timeIntervalSince(lastAttempt) < refreshCooldownInterval {
            print("Too soon to refresh weather")
            return
        }

        guard let provider = locationManager else {
            print("No location provider for WeatherManager")
            error = WeatherError.locationProviderMissing
            return
        }
        do {
            let loc = try await provider.currentLocation()
            try await fetch(for: loc)
            print("Got latest weather")
        } catch {
            print("WeatherManager: Failed to refresh: \(error)")
            self.error = error
        }
    }

    /// Core fetch for a specific location.
    func fetch(for location: CLLocation) async throws {
        // Global cooldown gate (applies to streaming and manual)
        if let lastAttempt = lastRequestAttempt,
           Date().timeIntervalSince(lastAttempt) < refreshCooldownInterval {
            return
        }

        // Throttle by time + distance when driven by a stream
        if let last = lastLocation,
           let lastTime = lastUpdated {
            let farEnough = location.distance(from: last) >= minDistanceChange
            let oldEnough = Date().timeIntervalSince(lastTime) >= minUpdateInterval
            if !farEnough && !oldEnough { return }
        }

        // Mark the attempt now to protect against races/spikes
        lastRequestAttempt = Date()

        isFetching = true
        error = nil
        defer { isFetching = false }

        let now = Date()
        let current = try await service.weather(for: location, including: .current)

        self.temperature = current.temperature
        self.pressure    = current.pressure
        self.humidity    = current.humidity
        self.condition   = current.condition
        self.lastUpdated = now
        self.lastLocation = location
    }

    // MARK: - Stream listening
    private func startListening(to provider: LocationManager) {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await loc in provider.locationUpdates() {
                if Task.isCancelled { break }
                do {
                    try await self.fetch(for: loc)
                } catch {
                    self.error = error
                }
            }
        }
    }

    // MARK: - UI conveniences

    var temperatureString: String? {
        guard let t = temperature else { return nil }
        let fmt = MeasurementFormatter()
        fmt.unitOptions = .naturalScale
        // Configure number formatter to show zero decimal places
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        fmt.numberFormatter = nf
        return fmt.string(from: t)
    }

    var pressureString: String? {
        guard let p = pressure else { return nil }
        let fmt = MeasurementFormatter()
        fmt.unitOptions = .providedUnit
        // Configure number formatter to show zero decimal places
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        fmt.numberFormatter = nf
        return fmt.string(from: p)
    }

    var humidityPercentString: String? {
        guard let h = humidity else { return nil }
        let nf = NumberFormatter()
        nf.numberStyle = .percent
        return nf.string(from: NSNumber(value: h))
    }
}
