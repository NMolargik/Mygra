//
//  PressureDropTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("PressureDropDetector")
struct PressureDropTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func series(_ values: [Double]) -> [PressureSample] {
        values.enumerated().map { PressureSample(date: t0.addingTimeInterval(Double($0.offset) * 3600), hpa: $0.element) }
    }

    private let five12 = PressureDropThreshold(dropHpa: 5, windowHours: 12)

    @Test("a steady series has no drops")
    func steady() {
        #expect(PressureDropDetector.drops(in: series([1015, 1015, 1014, 1015, 1016]), threshold: five12).isEmpty)
    }

    @Test("a fall that meets the threshold within the window is one drop")
    func simpleDrop() {
        let drops = PressureDropDetector.drops(in: series([1016, 1015, 1013, 1011, 1010, 1010]), threshold: five12)
        #expect(drops.count == 1)
        #expect(drops[0].fromHpa == 1016)
        #expect(drops[0].toHpa == 1010)
        #expect(drops[0].dropHpa == 6)
        #expect(drops[0].start == t0)
    }

    @Test("a fall slower than the window does not count")
    func tooSlow() {
        // 1 hPa per 4 hours: 3 hours window never sees 5 hPa.
        let slow = series(stride(from: 1020.0, through: 1000.0, by: -1).map { $0 })
        let threshold = PressureDropThreshold(dropHpa: 5, windowHours: 3)
        #expect(PressureDropDetector.drops(in: slow, threshold: threshold).isEmpty)
        #expect(!PressureDropDetector.drops(in: slow, threshold: PressureDropThreshold(dropHpa: 5, windowHours: 6)).isEmpty)
    }

    @Test("exactly the threshold counts, just under does not")
    func boundary() {
        #expect(PressureDropDetector.drops(in: series([1015, 1010]), threshold: five12).count == 1)
        #expect(PressureDropDetector.drops(in: series([1015, 1010.1]), threshold: five12).isEmpty)
    }

    @Test("a long fall merges into one drop and separate falls stay separate")
    func merging() {
        let long = PressureDropDetector.drops(in: series([1020, 1018, 1016, 1014, 1012, 1010, 1008, 1006]), threshold: five12)
        #expect(long.count == 1)
        #expect(long[0].toHpa == 1006)

        let twoFalls = series([1020, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1014, 1020, 1014])
        let result = PressureDropDetector.drops(in: twoFalls, threshold: PressureDropThreshold(dropHpa: 5, windowHours: 3))
        #expect(result.count == 2)
    }

    @Test("input order does not matter")
    func unsorted() {
        let samples = series([1016, 1010]).reversed()
        #expect(PressureDropDetector.drops(in: Array(samples), threshold: five12).count == 1)
    }

    @Test("the threshold clamps to sensible values")
    func clamping() {
        #expect(PressureDropThreshold(dropHpa: 0, windowHours: 5).dropHpa == 2)
        #expect(PressureDropThreshold(dropHpa: 99, windowHours: 5).dropHpa == 12)
        #expect(PressureDropThreshold(dropHpa: 5, windowHours: 5).windowHours == PressureDropThreshold.default.windowHours)
    }

    @Test("the alert covers drops under way, just finished, or forecast soon")
    func alertWindow() {
        let drop = PressureDrop(start: t0, end: t0.addingTimeInterval(4 * 3600), fromHpa: 1016, toHpa: 1009)
        // Under way.
        #expect(PressureDropDetector.alertDrop(in: [drop], now: t0.addingTimeInterval(2 * 3600)) == drop)
        // Finished 2 hours ago.
        #expect(PressureDropDetector.alertDrop(in: [drop], now: t0.addingTimeInterval(6 * 3600)) == drop)
        // Finished 5 hours ago: stale.
        #expect(PressureDropDetector.alertDrop(in: [drop], now: t0.addingTimeInterval(9 * 3600)) == nil)
        // Forecast to start in 5 hours.
        #expect(PressureDropDetector.alertDrop(in: [drop], now: t0.addingTimeInterval(-5 * 3600)) == drop)
        // Forecast to start in 8 hours: too early to warn.
        #expect(PressureDropDetector.alertDrop(in: [drop], now: t0.addingTimeInterval(-8 * 3600)) == nil)
    }

    @Test("attacks during or shortly after a drop are counted")
    func attacksFollowing() {
        let drop = PressureDrop(start: t0, end: t0.addingTimeInterval(4 * 3600), fromHpa: 1016, toHpa: 1009)
        let attacks = [t0.addingTimeInterval(2 * 3600), t0.addingTimeInterval(9 * 3600), t0.addingTimeInterval(11 * 3600), t0.addingTimeInterval(-3600)]
        #expect(PressureDropDetector.attacksFollowingDrops(attacks, drops: [drop]) == 2)
    }

    @Test("a qualifying drop makes the weather high risk and shows in the alert text")
    func riskIntegration() {
        let drop = PressureDrop(start: t0, end: t0.addingTimeInterval(4 * 3600), fromHpa: 1020, toHpa: 1014)
        let input = WeatherRiskInput(humidity: 0.4, pressureHpa: 1014, condition: .clear, pressureDrop: drop)
        #expect(WeatherRisk.isHighRisk(input))
        #expect(WeatherRisk.notificationContent(input).body.contains("falling 6 hPa"))
        #expect(!WeatherRisk.isHighRisk(WeatherRiskInput(humidity: 0.4, pressureHpa: 1014, condition: .clear)))
    }

    @Test("the stored threshold round-trips and defaults when unset")
    func store() {
        let defaults = FakeKeyValueStore()
        let store = PressureDropThresholdStore(defaults: defaults)
        #expect(store.load() == .default)
        store.save(PressureDropThreshold(dropHpa: 8, windowHours: 6))
        #expect(store.load() == PressureDropThreshold(dropHpa: 8, windowHours: 6))
    }

    @Test("the explanation honors units and avoids em dashes")
    func explanation() {
        let metric = PressureDropDetector.explanation(.default, useMetricUnits: true)
        #expect(metric.contains("5 hPa"))
        #expect(metric.contains("12 hours"))
        #expect(!metric.contains("—"))
        #expect(PressureDropDetector.explanation(.default, useMetricUnits: false).contains("inHg"))
    }
}
