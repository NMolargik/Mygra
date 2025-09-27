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
import MapKit

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
    var error: Error?

    private(set) var temperature: Measurement<UnitTemperature>?
    private(set) var pressure: Measurement<UnitPressure>?
    /// 0.0 ... 1.0 (57% => 0.57)
    private(set) var humidity: Double?
    private(set) var condition: WeatherCondition?

    // Last known location used for weather and its placemark
    @ObservationIgnored
    private var lastLocation: CLLocation?
    private(set) var placemark: MKPlacemark?

    // Throttling knobs
    /// Minimum time between successive successful updates (used with distance gating when streaming)
    var minUpdateInterval: TimeInterval = 10 * 60 // 10 minutes
    /// Minimum distance change required to fetch again when streaming
    var minDistanceChange: CLLocationDistance = 500 // meters

    /// Global cooldown to avoid costly WeatherKit hits from any trigger (manual, initial load, streaming).
    /// Only successful requests advance this cooldown. If a successful request was made less than this interval ago, we skip new requests.
    /// Set to 1 hour to limit updates and reduce WeatherKit costs.
    var refreshCooldownInterval: TimeInterval = 60 * 60 // 1 hour

    // Internal
    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?
    @ObservationIgnored
    private var lastRequestAttempt: Date?

    // MapKit/CoreLocation geocoder wrapper
    @ObservationIgnored
    private var geocoder: GeocoderHolder = GeocoderHolder()

    // MARK: - Cached formatters
    private static let shortTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()

    private static let tempFormatter: MeasurementFormatter = {
        let fmt = MeasurementFormatter()
        fmt.unitOptions = .naturalScale
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        fmt.numberFormatter = nf
        return fmt
    }()

    private static let pressureFormatter: MeasurementFormatter = {
        let fmt = MeasurementFormatter()
        fmt.unitOptions = .providedUnit
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        fmt.numberFormatter = nf
        return fmt
    }()

    private static let percentFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .percent
        return nf
    }()

    // MARK: - Init / deinit
    init(service: WeatherService = .shared, locationManager: LocationManager? = nil) {
        self.service = service
        self.locationManager = locationManager
    }

    @MainActor
    deinit {
        updatesTask?.cancel()
        geocoder.cancel()
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
        // Global cooldown gate (manual refresh): show transient error indicating next eligible time
        if let lastAttempt = lastRequestAttempt,
           Date().timeIntervalSince(lastAttempt) < refreshCooldownInterval {
            let next = lastAttempt.addingTimeInterval(refreshCooldownInterval)
            let msg = "You can refresh weather again at \(Self.shortTimeFormatter.string(from: next))."
            setTransientError(CooldownError(message: msg), duration: 3.0)
            print("Too soon to refresh weather. Next eligible: \(next)")
            return
        }

        guard let provider = locationManager else {
            print("No location provider for WeatherManager")
            error = WeatherError.locationProviderMissing
            return
        }
        do {
            let loc: CLLocation
            do {
                loc = try await provider.currentLocation()
            } catch {
                self.error = WeatherError.locationUnavailable
                return
            }
            try await fetch(for: loc)
            print("Got latest weather")
        } catch {
            if error is WeatherError {
                self.error = error
            } else {
                self.error = WeatherError.weatherServiceFailed
            }
            print("WeatherManager: Failed to refresh: \(error)")
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

        // Record successful fetch time for cooldown gating
        self.lastRequestAttempt = now

        // Kick off reverse geocoding (non-blocking)
        await reverseGeocodeIfNeeded(for: location)
    }

    // MARK: - Transient error helper
    private func setTransientError(_ error: Error, duration: TimeInterval) {
        self.error = error
        let currentDescription = (error as NSError).localizedDescription
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            // Only clear if the error hasn't changed since
            let existingDescription = (self.error as NSError?)?.localizedDescription
            if existingDescription == currentDescription {
                self.error = nil
            }
        }
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

    // MARK: - Reverse geocoding

    private func reverseGeocodeIfNeeded(for location: CLLocation) async {
        // If we already have a placemark for (roughly) the same spot, skip.
        if let _ = placemark, let last = lastLocation {
            let d = location.distance(from: last)
            if d < 100 { return } // within 100m: keep existing placemark
        }

        // Cancel any in-flight geocode to avoid piling up
        geocoder.cancel()

        do {
            let pm = try await geocoder.reverseGeocode(location)
            self.placemark = pm
        } catch {
            // Non-fatal; we simply won't show a location string
            // Optionally store the error if needed
            self.error = WeatherError.geocodingFailed
        }
    }

    // MARK: - UI conveniences

    var temperatureString: String? {
        guard let t = temperature else { return nil }
        return Self.tempFormatter.string(from: t)
    }

    var pressureString: String? {
        guard let p = pressure else { return nil }
        return Self.pressureFormatter.string(from: p)
    }

    var humidityPercentString: String? {
        guard let h = humidity else { return nil }
        return Self.percentFormatter.string(from: NSNumber(value: h))
    }

    // Human-readable location name (e.g., "Seattle, WA" or "Seattle, USA")
    var locationString: String? {
        guard let pm = placemark else { return nil }
        if let city = pm.locality, let admin = pm.administrativeArea, !admin.isEmpty {
            return "\(city), \(admin)"
        }
        if let city = pm.locality, let country = pm.isoCountryCode {
            return "\(city), \(country)"
        }
        return pm.locality ?? pm.name
    }
}

private struct CooldownError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
private final class GeocoderHolder {
    // Use CoreLocation's geocoder for broad iOS compatibility.
    private let geocoder = CLGeocoder()

    func cancel() {
        geocoder.cancelGeocode()
    }

    // Keep reverse geocoding on the main actor (it feeds UI state).
    func reverseGeocode(_ location: CLLocation) async throws -> MKPlacemark? {
        // Cancel any in-flight request before starting a new one
        cancel()

        // Prefer the async/await API when available; fall back to continuation otherwise.
        if #available(iOS 15.0, *) {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let first = placemarks.first {
                return MKPlacemark(placemark: first)
            } else {
                return nil
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let first = placemarks?.first {
                        continuation.resume(returning: MKPlacemark(placemark: first))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}
