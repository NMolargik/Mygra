//
//  WeatherRiskTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("WeatherRisk")
struct WeatherRiskTests {
    @Test func calmConditionsAreLowRisk() {
        #expect(!WeatherRisk.isHighRisk(WeatherRiskInput(humidity: 0.5, pressureHpa: 1015, condition: .clear)))
    }

    @Test func highHumidityIsHighRisk() {
        #expect(WeatherRisk.isHighRisk(WeatherRiskInput(humidity: 0.70, pressureHpa: 1015, condition: .clear)))
    }

    @Test func lowPressureIsHighRisk() {
        #expect(WeatherRisk.isHighRisk(WeatherRiskInput(humidity: 0.3, pressureHpa: 1007.9, condition: .clear)))
    }

    @Test func strongStormsAreHighRisk() {
        #expect(WeatherRisk.isHighRisk(WeatherRiskInput(humidity: 0.3, pressureHpa: 1020, condition: .strongStorms)))
    }

    @Test func missingReadingsAreLowRisk() {
        #expect(!WeatherRisk.isHighRisk(WeatherRiskInput(humidity: nil, pressureHpa: nil, condition: nil)))
    }

    @Test func boundaryPressureIsNotHighRisk() {
        #expect(!WeatherRisk.isHighRisk(WeatherRiskInput(humidity: 0.3, pressureHpa: 1008.0, condition: .clear)))
    }

    @Test func notifiesOnlyOnTransitionIntoHighRisk() {
        let high = WeatherRiskInput(humidity: 0.9, pressureHpa: 1000, condition: .rain)
        let low = WeatherRiskInput(humidity: 0.3, pressureHpa: 1020, condition: .clear)
        #expect(WeatherRisk.shouldNotify(input: high, wasHighRisk: false))
        #expect(!WeatherRisk.shouldNotify(input: high, wasHighRisk: true))
        #expect(!WeatherRisk.shouldNotify(input: low, wasHighRisk: false))
    }

    @Test func notificationContentMentionsReadings() {
        let content = WeatherRisk.notificationContent(WeatherRiskInput(humidity: 0.8, pressureHpa: 1000, condition: .rain))
        #expect(content.body.contains("1000 hPa"))
        #expect(content.body.contains("80% humidity"))
        #expect(content.body.contains("Rain"))
        #expect(!content.title.isEmpty)
    }
}
