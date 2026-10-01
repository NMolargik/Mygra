//
//  LocationManager.swift
//  MygraServices
//
//  CoreLocation authorization, one-shot fixes, and a continuous update stream.
//

import Foundation
import CoreLocation
import Observation
import MygraCore

nonisolated public enum LocationError: LocalizedError {
    case notAuthorized
    case requestInProgress
    case updateFailed(underlying: any Error)
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthorized: return String(localized: "Location access is not authorized.")
        case .requestInProgress: return String(localized: "A location request is already in progress.")
        case .updateFailed: return String(localized: "Failed to obtain a location update.")
        case .unavailable: return String(localized: "Location services are unavailable.")
        }
    }
}

@MainActor
@Observable
public final class LocationManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Observable state
    public private(set) var isAuthorized: Bool = false
    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public private(set) var lastLocation: CLLocation?

    // MARK: - Private
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var streamContinuation: AsyncStream<CLLocation>.Continuation?
    @ObservationIgnored private var oneShotContinuation: CheckedContinuation<CLLocation, any Error>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        updateAuthorization(from: manager.authorizationStatus)
    }

    // MARK: - Authorization

    /// Prompts when undetermined; otherwise just refreshes the observable status.
    public func requestAuthorization() {
        let status = manager.authorizationStatus
        updateAuthorization(from: status)
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - One-shot location

    public func currentLocation() async throws -> CLLocation {
        if isAuthorized, let location = manager.location {
            lastLocation = location
            return location
        }
        guard isAuthorized else { throw LocationError.notAuthorized }
        guard oneShotContinuation == nil else { throw LocationError.requestInProgress }

        manager.requestLocation()
        return try await withCheckedThrowingContinuation { continuation in
            self.oneShotContinuation = continuation
        }
    }

    // MARK: - Continuous updates

    public func locationUpdates() -> AsyncStream<CLLocation> {
        guard isAuthorized else {
            return AsyncStream { $0.finish() }
        }
        manager.startUpdatingLocation()
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.manager.stopUpdatingLocation()
                    self.streamContinuation = nil
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization(from: manager.authorizationStatus)
        if !isAuthorized, let continuation = oneShotContinuation {
            oneShotContinuation = nil
            continuation.resume(throwing: LocationError.notAuthorized)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        lastLocation = last
        if let continuation = oneShotContinuation {
            oneShotContinuation = nil
            continuation.resume(returning: last)
        }
        streamContinuation?.yield(last)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        if let continuation = oneShotContinuation {
            oneShotContinuation = nil
            continuation.resume(throwing: LocationError.updateFailed(underlying: error))
        }
        // Streams stay open through transient errors.
    }

    // MARK: - Helpers

    private func updateAuthorization(from status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: isAuthorized = true
        default: isAuthorized = false
        }
    }
}
