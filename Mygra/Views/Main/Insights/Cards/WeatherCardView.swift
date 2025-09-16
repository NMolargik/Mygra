//
//  WeatherCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation
import SwiftUI
import WeatherKit
import CoreLocation

struct WeatherCardView: View {
    let temperatureString: String?
    let pressureString: String?
    let humidityPercentString: String?
    let condition: WeatherCondition?
    let lastUpdated: Date?
    let isFetching: Bool
    let error: Error?
    let onRefresh: () -> Void
    let locationString: String?

    // Local state to trigger SF Symbol bounce when condition updates
    @State private var bounceFlag: Bool = false
    @State private var previousCondition: WeatherCondition?

    var body: some View {
        Group {
            if let temp = temperatureString,
               let press = pressureString,
               let humid = humidityPercentString,
               let condition {
                HStack(spacing: 12) {
                    let layers = symbolLayerColors(for: condition)
                    Image(systemName: symbolName(for: condition))
                        .font(.system(size: 32))
                        .foregroundStyle(layers.layer1.gradient, layers.layer2.gradient)
                        .symbolEffect(.bounce, options: .repeat(1), value: bounceFlag)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(conditionLabel(for: condition)) • \(temp)")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Label(press, systemImage: "gauge.with.dots.needle.bottom.50percent")
                                Label(humid, systemImage: "humidity")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            if let location = locationString, !location.isEmpty {
                                Text(location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        
                        // Attribution footer
                        HStack(spacing: 6) {
                            Text(" Weather")
                            Text("•")
                                .accessibilityHidden(true)
                            Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let updated = lastUpdated {
                            Text(updated, style: .time)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if isFetching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button(action: onRefresh) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if let message = userFacingErrorMessage(from: error) {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                Spacer()
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(6)
                        }
                        .transition(.opacity)
                    }
                }
                // Detect condition changes and trigger a single bounce
                .onChange(of: condition) {
                    switch (previousCondition, condition as WeatherCondition?) {
                    case let (old?, new?) where old != new:
                        bounceFlag.toggle()
                    case (nil, .some):
                        bounceFlag.toggle()
                    default:
                        break
                    }
                    previousCondition = condition
                }
                // Initialize previousCondition and optionally bounce on appear
                .onAppear {
                    if previousCondition == nil {
                        previousCondition = condition
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "location")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weather Unavailable")
                            .font(.headline)
                        Text(unavailableSubtitle(for: error))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    Button("Refresh", action: onRefresh)
                        .buttonStyle(.bordered)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Error presentation

    private func userFacingErrorMessage(from error: Error?) -> String? {
        guard let error else { return nil }
        let ns = error as NSError

        if ns.domain == kCLErrorDomain as String {
            switch CLError.Code(rawValue: ns.code) {
            case .some(.locationUnknown),
                 .some(.deferredAccuracyTooLow),
                 .some(.deferredCanceled),
                 .some(.deferredFailed),
                 .some(.deferredNotUpdatingLocation),
                 .some(.network),
                 .some(.denied),
                 .some(.regionMonitoringDenied),
                 .some(.regionMonitoringFailure),
                 .some(.regionMonitoringSetupDelayed),
                 .some(.geocodeFoundNoResult),
                 .some(.geocodeCanceled),
                 .some(.geocodeFoundPartialResult),
                 .some(.rangingUnavailable),
                 .some(.rangingFailure),
                 .some(.promptDeclined):
                return nil
            default:
                return "We couldn’t get your location. Try refreshing."
            }
        }

        if ns.domain == NSURLErrorDomain {
            return "Network issue fetching weather. Check your connection."
        }

        return "Couldn’t update weather right now."
    }

    private func unavailableSubtitle(for error: Error?) -> String {
        guard let error = error as NSError? else {
            return "Enable location and refresh to see current weather."
        }
        if error.domain == kCLErrorDomain as String {
            switch CLError.Code(rawValue: error.code) {
            case .some(.denied), .some(.promptDeclined):
                return "Location access is needed to show local weather."
            case .some(.network):
                return "Network issue. Check your connection and try again."
            default:
                return "Weather data isn’t available yet. Try refreshing."
            }
        }
        if error.domain == NSURLErrorDomain {
            return "Network issue. Check your connection and try again."
        }
        return "Weather data isn’t available yet. Try refreshing."
    }

    // MARK: - Labels and symbols

    private func conditionLabel(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return "Clear"
        case .mostlyClear: return "Mostly Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .mostlyCloudy: return "Mostly Cloudy"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy Rain"
        case .strongStorms: return "Thunderstorms"
        case .snow: return "Snow"
        case .flurries: return "Flurries"
        case .sleet: return "Sleet"
        case .freezingRain: return "Freezing Rain"
        case .haze: return "Haze"
        case .foggy: return "Fog"
        case .windy: return "Windy"
        case .blowingSnow: return "Blowing Snow"
        case .frigid: return "Frigid"
        case .hot: return "Hot"
        case .blizzard: return "Blizzard"
        case .smoky: return "Smoky"
        default: return "Weather"
        }
    }

    private func symbolName(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy: return "cloud.fill"
        case .drizzle, .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .strongStorms: return "cloud.bolt.rain.fill"
        case .snow, .flurries: return "cloud.snow.fill"
        case .sleet, .freezingRain: return "cloud.sleet.fill"
        case .haze, .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        case .blowingSnow, .blizzard: return "wind.snow"
        case .frigid: return "thermometer.snowflake"
        case .hot: return "thermometer.sun.fill"
        case .smoky: return "smoke.fill"
        default:
            return "cloud"
        }
    }

    // Returns colors ordered to match the SF Symbol layer order for the chosen symbol.
    private func symbolLayerColors(for condition: WeatherCondition) -> (layer1: Color, layer2: Color) {
        switch condition {
        case .clear, .mostlyClear:
            // sun.max.fill is effectively single-layer; use same color twice
            return (.yellow, .yellow)
        case .partlyCloudy:
            // cloud.sun.fill => layer1=cloud, layer2=sun
            return (.gray, .yellow)
        case .cloudy, .mostlyCloudy:
            // cloud.fill => single-layer
            return (.gray, .gray)
        case .drizzle, .rain:
            // cloud.rain.fill => layer1=cloud, layer2=rain
            return (.gray, .blue)
        case .heavyRain:
            // cloud.heavyrain.fill => layer1=cloud, layer2=heavy rain
            return (.gray, Color.blue.opacity(0.9))
        case .strongStorms:
            // cloud.bolt.rain.fill => layer1=cloud, layer2=bolt+rain
            return (.gray, .indigo)
        case .snow, .flurries:
            // cloud.snow.fill => layer1=cloud, layer2=snow
            return (.gray, .cyan)
        case .sleet, .freezingRain:
            // cloud.sleet.fill => layer1=cloud, layer2=sleet
            return (.gray, .teal)
        case .haze, .foggy:
            // cloud.fog.fill => layer1=cloud, layer2=fog
            return (.gray, .gray.opacity(0.6))
        case .windy:
            // wind => single-layer
            return (.teal, .teal)
        case .blowingSnow, .blizzard:
            // wind.snow may render as single-layer on some OS versions; still provide two tones
            return (.gray, .cyan)
        case .frigid:
            // thermometer.snowflake is often single-layer in monochrome contexts
            return (.blue, .blue)
        case .hot:
            // thermometer.sun.fill may be multi-layer, but safe default
            return (.red, .orange)
        case .smoky:
            // smoke.fill => single-layer-ish
            return (.brown, .brown)
        default:
            return (.gray, .gray.opacity(0.7))
        }
    }
}

// MARK: - Previews

#Preview("Sunny in Indy") {
    WeatherCardView(
        temperatureString: "78°",
        pressureString: "29.9 inHg",
        humidityPercentString: "45% RH",
        condition: .clear,
        lastUpdated: Date(),
        isFetching: false,
        error: nil,
        onRefresh: {},
        locationString: "Indianapolis, IN"
    )
    .padding()
}

#Preview("Fetching…") {
    WeatherCardView(
        temperatureString: "78°",
        pressureString: "29.9 inHg",
        humidityPercentString: "45% RH",
        condition: .partlyCloudy,
        lastUpdated: Date(),
        isFetching: true,
        error: nil,
        onRefresh: {},
        locationString: "Indianapolis, IN"
    )
    .padding()
}

#Preview("Network Error / Unavailable") {
    // Simulate a network error to drive the unavailable state
    let sampleError = NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]) as Error

    return WeatherCardView(
        temperatureString: nil,
        pressureString: nil,
        humidityPercentString: nil,
        condition: nil,
        lastUpdated: nil,
        isFetching: false,
        error: sampleError,
        onRefresh: {},
        locationString: nil
    )
    .padding()
}
