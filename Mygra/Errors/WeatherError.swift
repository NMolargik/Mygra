//
//  WeatherError.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation

enum WeatherError: LocalizedError {
    case locationProviderMissing
    case locationUnavailable
    case weatherServiceFailed
    case geocodingFailed
    var errorDescription: String? {
        switch self {
            case .locationProviderMissing: return "No location provider has been set."
            case .locationUnavailable: return "Unable to get current location."
            case .weatherServiceFailed: return "Failed to fetch weather data."
            case .geocodingFailed: return "Failed to resolve location name."
        }
    }
}
