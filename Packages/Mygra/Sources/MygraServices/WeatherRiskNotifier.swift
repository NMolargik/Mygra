//
//  WeatherRiskNotifier.swift
//  MygraServices
//
//  Refreshes current conditions and posts a notification when the weather transitions
//  into migraine-risk territory. Pure over the `CurrentWeatherProviding` and
//  `LocalNotifying` seams (host-tested with fakes); the app schedules it from a
//  background task and a foreground timer.
//

import Foundation
import MygraCore
import os

@MainActor
public final class WeatherRiskNotifier {
    private let weather: any CurrentWeatherProviding
    private let notifications: any LocalNotifying
    private let now: () -> Date

    /// Whether the last check was high risk (notifications fire on the transition only).
    public private(set) var wasHighRisk = false

    public init(weather: any CurrentWeatherProviding, notifications: any LocalNotifying, now: @escaping () -> Date = Date.init) {
        self.weather = weather
        self.notifications = notifications
        self.now = now
    }

    /// Refreshes the weather and notifies on a new high-risk reading. Never requests
    /// permission; the notification is skipped when it hasn't been granted.
    @discardableResult
    public func checkAndNotify() async -> Bool {
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
