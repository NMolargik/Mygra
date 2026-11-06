//
//  WeatherRiskNotifier.swift
//  MygraServices
//
//  Refreshes current conditions and posts a notification when the weather transitions
//  into migraine-risk territory. Pure over the `CurrentWeatherProviding` and
//  `LocalNotifying` seams (host-tested with fakes); the app schedules it from a
//  background task and a foreground timer. Weather-risk alerts are a Mygra Plus feature,
//  so the check is a no-op without the entitlement.
//

import Foundation
import MygraCore
import os

@MainActor
public final class WeatherRiskNotifier {
    private let weather: any CurrentWeatherProviding
    private let notifications: any LocalNotifying
    private let entitlement: any EntitlementProviding
    private let now: () -> Date

    /// Whether the last check was high risk (notifications fire on the transition only).
    public private(set) var wasHighRisk = false

    public init(
        weather: any CurrentWeatherProviding,
        notifications: any LocalNotifying,
        entitlement: any EntitlementProviding,
        now: @escaping () -> Date = Date.init
    ) {
        self.weather = weather
        self.notifications = notifications
        self.entitlement = entitlement
        self.now = now
    }

    /// Refreshes the weather and notifies on a new high-risk reading. Never requests
    /// permission; the notification is skipped when it hasn't been granted. Without
    /// Plus nothing runs (the dashboard refreshes current conditions on its own).
    @discardableResult
    public func checkAndNotify() async -> Bool {
        guard entitlement.gate.unlocks(.weatherRisk) else { return false }
        await weather.refresh()
        let input = weather.riskInput
        let high = WeatherRisk.isHighRisk(input)
        defer { wasHighRisk = high }

        guard WeatherRisk.shouldNotify(input: input, wasHighRisk: wasHighRisk) else { return false }
        guard await notifications.isAuthorized else { return false }

        let content = WeatherRisk.notificationContent(input)
        do {
            try await notifications.send(
                title: content.title,
                body: content.body,
                identifier: "weather-risk-\(Int(now().timeIntervalSince1970))"
            )
            return true
        } catch {
            Log.weather.error("Failed to send weather-risk notification: \(error.localizedDescription)")
            return false
        }
    }
}
