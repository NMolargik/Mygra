//
//  WeatherError.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation

enum WeatherError: LocalizedError {
    case locationProviderMissing
    var errorDescription: String? {
        switch self {
            case .locationProviderMissing: "No location provider has been set."
        }
    }
}
