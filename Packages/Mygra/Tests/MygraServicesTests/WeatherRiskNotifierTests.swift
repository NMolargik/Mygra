//
//  WeatherRiskNotifierTests.swift
//  MygraServicesTests
//
//  The weather-risk check over fake weather and notification seams.
//

import Foundation
import Testing
import MygraCore
@testable import MygraServices

@MainActor
private final class FakeWeather: CurrentWeatherProviding {
    var riskInput: WeatherRiskInput
    var pressureSeries: [PressureSample] = []
    private(set) var refreshCount = 0
    init(_ input: WeatherRiskInput) { riskInput = input }
    func refresh() async { refreshCount += 1 }
}

@MainActor
private final class FakeNotifier: LocalNotifying {
    var authorized = true
    var shouldFail = false
    private(set) var sent: [(title: String, body: String, identifier: String)] = []
    var isAuthorized: Bool { get async { authorized } }
    func send(title: String, body: String, identifier: String) async throws {
        if shouldFail { throw NotificationError.authorizationDenied }
        sent.append((title, body, identifier))
    }
}

@Suite("WeatherRiskNotifier")
@MainActor
struct WeatherRiskNotifierTests {
    private let stormy = WeatherRiskInput(humidity: 0.9, pressureHpa: 1000, condition: .strongStorms)
    private let calm = WeatherRiskInput(humidity: 0.3, pressureHpa: 1020, condition: .clear)

    @Test func notifiesOnceWhenRiskRises() async {
        let weather = FakeWeather(stormy)
        let notifier = FakeNotifier()
        let sut = WeatherRiskNotifier(weather: weather, notifications: notifier, entitlement: FixedEntitlement(hasPlus: true), now: { Date(timeIntervalSince1970: 1_000) })

        #expect(await sut.checkAndNotify())
        #expect(weather.refreshCount == 1)
        #expect(notifier.sent.count == 1)
        #expect(notifier.sent.first?.identifier == "weather-risk-1000")
        #expect(notifier.sent.first?.body.contains("1000 hPa") == true)

        // Still stormy: no repeat.
        #expect(await sut.checkAndNotify() == false)
        #expect(notifier.sent.count == 1)

        // Calm, then stormy again: fires again on the new transition.
        weather.riskInput = calm
        #expect(await sut.checkAndNotify() == false)
        weather.riskInput = stormy
        #expect(await sut.checkAndNotify())
        #expect(notifier.sent.count == 2)
    }

    @Test func skipsWhenNotAuthorizedButRemembersRisk() async {
        let weather = FakeWeather(stormy)
        let notifier = FakeNotifier()
        notifier.authorized = false
        let sut = WeatherRiskNotifier(weather: weather, notifications: notifier, entitlement: FixedEntitlement(hasPlus: true))

        #expect(await sut.checkAndNotify() == false)
        #expect(notifier.sent.isEmpty)
        #expect(sut.wasHighRisk)
    }

    @Test("without Plus the check neither refreshes nor notifies")
    func freeTierIsANoOp() async {
        let weather = FakeWeather(stormy)
        let notifier = FakeNotifier()
        let entitlement = FixedEntitlement(hasPlus: false)
        let sut = WeatherRiskNotifier(weather: weather, notifications: notifier, entitlement: entitlement)

        #expect(await sut.checkAndNotify() == false)
        #expect(weather.refreshCount == 0)
        #expect(notifier.sent.isEmpty)
        #expect(sut.wasHighRisk == false)

        // Unlocking Plus turns the same notifier on.
        entitlement.hasPlus = true
        #expect(await sut.checkAndNotify())
        #expect(notifier.sent.count == 1)
    }

    @Test func deliveryFailureIsReportedNotThrown() async {
        let notifier = FakeNotifier()
        notifier.shouldFail = true
        let sut = WeatherRiskNotifier(weather: FakeWeather(stormy), notifications: notifier, entitlement: FixedEntitlement(hasPlus: true))
        #expect(await sut.checkAndNotify() == false)
    }

    @Test func aForecastPressureDropAlertsEvenWithCalmReadings() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let weather = FakeWeather(calm)
        weather.pressureSeries = (0..<8).map { PressureSample(date: now.addingTimeInterval(Double($0 - 1) * 3600), hpa: 1022 - Double($0) * 1.5) }
        let notifier = FakeNotifier()
        let sut = WeatherRiskNotifier(weather: weather, notifications: notifier, entitlement: FixedEntitlement(hasPlus: true), defaults: FakeDefaults(), now: { now })

        #expect(await sut.checkAndNotify())
        #expect(notifier.sent.first?.body.contains("falling") == true)
    }

    @Test func aLooserUserThresholdSilencesTheSameDrop() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let weather = FakeWeather(calm)
        weather.pressureSeries = (0..<8).map { PressureSample(date: now.addingTimeInterval(Double($0 - 1) * 3600), hpa: 1022 - Double($0) * 1.5) }
        let defaults = FakeDefaults()
        PressureDropThresholdStore(defaults: defaults).save(PressureDropThreshold(dropHpa: 12, windowHours: 12))
        let sut = WeatherRiskNotifier(weather: weather, notifications: FakeNotifier(), entitlement: FixedEntitlement(hasPlus: true), defaults: defaults, now: { now })

        #expect(await sut.checkAndNotify() == false)
    }
}

private final class FakeDefaults: KeyValueStoring, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}
