//
//  WeatherRiskTests.swift
//  MygraTests
//

import Foundation
import Testing
import WeatherKit
@testable import Mygra

@Suite("WeatherRisk")
struct WeatherRiskTests {
    @Test func calmConditionsAreLowRisk() {
        let input = WeatherRiskInput(humidity: 0.5, pressureHpa: 1015, condition: .clear)
        #expect(!WeatherRisk.isHighRisk(input))
    }

    @Test func highHumidityIsHighRisk() {
        let input = WeatherRiskInput(humidity: 0.70, pressureHpa: 1015, condition: .clear)
        #expect(WeatherRisk.isHighRisk(input))
    }

    @Test func lowPressureIsHighRisk() {
        let input = WeatherRiskInput(humidity: 0.3, pressureHpa: 1007.9, condition: .clear)
        #expect(WeatherRisk.isHighRisk(input))
    }

    @Test func strongStormsAreHighRisk() {
        let input = WeatherRiskInput(humidity: 0.3, pressureHpa: 1020, condition: .strongStorms)
        #expect(WeatherRisk.isHighRisk(input))
    }

    @Test func missingReadingsAreLowRisk() {
        let input = WeatherRiskInput(humidity: nil, pressureHpa: nil, condition: nil)
        #expect(!WeatherRisk.isHighRisk(input))
    }

    @Test func boundaryPressureIsNotHighRisk() {
        let input = WeatherRiskInput(humidity: 0.3, pressureHpa: 1008.0, condition: .clear)
        #expect(!WeatherRisk.isHighRisk(input))
    }

    @Test func notificationContentMentionsReadings() {
        let input = WeatherRiskInput(humidity: 0.8, pressureHpa: 1000, condition: .rain)
        let content = WeatherRisk.notificationContent(input)
        #expect(content.body.contains("1000 hPa"))
        #expect(content.body.contains("80% humidity"))
        #expect(!content.title.isEmpty)
    }
}
