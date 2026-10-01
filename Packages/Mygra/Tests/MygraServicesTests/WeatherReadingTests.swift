//
//  WeatherReadingTests.swift
//  MygraServicesTests
//

import Foundation
import Testing
import WeatherKit
import MygraCore
@testable import MygraServices

@Suite("WeatherReading")
struct WeatherReadingTests {
    private let reading = WeatherReading(
        temperature: Measurement(value: 25, unit: .celsius),
        pressure: Measurement(value: 1013.25, unit: .hectopascals),
        humidity: 0.57,
        condition: .partlyCloudy,
        fetchedAt: Date(timeIntervalSince1970: 0)
    )

    @Test func formatsForBothUnitSystems() {
        #expect(reading.formattedTemperature(useMetricUnits: true) == "25°")
        #expect(reading.formattedTemperature(useMetricUnits: false) == "77°")
        #expect(reading.formattedPressure(useMetricUnits: true) == "1013 hPa")
        #expect(reading.formattedPressure(useMetricUnits: false) == "29.92 inHg")
        #expect(reading.formattedHumidity == "57%")
    }

    @Test func makesPersistedSnapshotInSIUnits() {
        let data = reading.makeWeatherData(createdAt: Date(timeIntervalSince1970: 5), locationDescription: "Seattle, WA")
        #expect(abs(data.barometricPressureHpa - 1013.25) < 0.001)
        #expect(data.temperatureCelsius == 25)
        #expect(abs(data.humidityPercent - 57) < 0.0001)
        #expect(data.condition == .partlyCloudy)
        #expect(data.locationDescription == "Seattle, WA")
        #expect(data.createdAt == Date(timeIntervalSince1970: 5))
    }

    @Test func everyWeatherKitConditionMapsToACase() {
        for condition in WeatherCondition.allCases {
            #expect(SkyCondition(rawValue: condition.rawValue) != nil, "missing \(condition.rawValue)")
            #expect(SkyCondition(condition).rawValue == condition.rawValue)
        }
    }
}
