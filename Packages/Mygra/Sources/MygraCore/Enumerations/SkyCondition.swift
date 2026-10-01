//
//  SkyCondition.swift
//  MygraCore
//
//  The persisted weather-condition bucket. Raw values mirror WeatherKit's
//  `WeatherCondition` case names one-for-one so records written by earlier releases
//  (which stored the WeatherKit enum directly) decode unchanged, while Core stays free
//  of WeatherKit. The mapping from WeatherKit lives in MygraServices.
//

import Foundation

nonisolated public enum SkyCondition: String, Codable, CaseIterable, Hashable, Sendable {
    case blizzard
    case blowingDust
    case blowingSnow
    case breezy
    case clear
    case cloudy
    case drizzle
    case flurries
    case foggy
    case freezingDrizzle
    case freezingRain
    case frigid
    case hail
    case haze
    case heavyRain
    case heavySnow
    case hot
    case hurricane
    case isolatedThunderstorms
    case mostlyClear
    case mostlyCloudy
    case partlyCloudy
    case rain
    case scatteredThunderstorms
    case sleet
    case smoky
    case snow
    case strongStorms
    case sunFlurries
    case sunShowers
    case thunderstorms
    case tropicalStorm
    case windy
    case wintryMix

    /// Human-friendly label for the condition.
    public var displayName: String {
        switch self {
        case .blizzard: return String(localized: "Blizzard")
        case .blowingDust: return String(localized: "Blowing Dust")
        case .blowingSnow: return String(localized: "Blowing Snow")
        case .breezy: return String(localized: "Breezy")
        case .clear: return String(localized: "Clear")
        case .cloudy: return String(localized: "Cloudy")
        case .drizzle: return String(localized: "Drizzle")
        case .flurries: return String(localized: "Flurries")
        case .foggy: return String(localized: "Fog")
        case .freezingDrizzle: return String(localized: "Freezing Drizzle")
        case .freezingRain: return String(localized: "Freezing Rain")
        case .frigid: return String(localized: "Frigid")
        case .hail: return String(localized: "Hail")
        case .haze: return String(localized: "Haze")
        case .heavyRain: return String(localized: "Heavy Rain")
        case .heavySnow: return String(localized: "Heavy Snow")
        case .hot: return String(localized: "Hot")
        case .hurricane: return String(localized: "Hurricane")
        case .isolatedThunderstorms: return String(localized: "Isolated Thunderstorms")
        case .mostlyClear: return String(localized: "Mostly Clear")
        case .mostlyCloudy: return String(localized: "Mostly Cloudy")
        case .partlyCloudy: return String(localized: "Partly Cloudy")
        case .rain: return String(localized: "Rain")
        case .scatteredThunderstorms: return String(localized: "Scattered Thunderstorms")
        case .sleet: return String(localized: "Sleet")
        case .smoky: return String(localized: "Smoky")
        case .snow: return String(localized: "Snow")
        case .strongStorms: return String(localized: "Thunderstorms")
        case .sunFlurries: return String(localized: "Sun Flurries")
        case .sunShowers: return String(localized: "Sun Showers")
        case .thunderstorms: return String(localized: "Thunderstorms")
        case .tropicalStorm: return String(localized: "Tropical Storm")
        case .windy: return String(localized: "Windy")
        case .wintryMix: return String(localized: "Wintry Mix")
        }
    }
}
