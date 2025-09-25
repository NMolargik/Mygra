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
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    let temperatureString: String?
    let pressureString: String?
    let humidityPercentString: String?
    let condition: WeatherCondition?
    let lastUpdated: Date?
    let isFetching: Bool
    let error: Error?
    let onRefresh: () -> Void
    let locationString: String?

    @State private var bounceFlag: Bool = false
    @State private var previousCondition: WeatherCondition?
    @State private var showErrorOverlay: Bool = false

    var body: some View {
        Group {
            if let temp = temperatureString,
               let press = pressureString,
               let humid = humidityPercentString,
               let condition {
                HStack(spacing: 15) {
                    condition.mygraSymbolView()
                        .font(.title)
                        .symbolEffect(.bounce, options: .repeat(1), value: bounceFlag)

                    VStack(alignment: .leading, spacing: 2) {
                        // Top row: condition + last updated time
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(condition.mygraConditionLabel)
                                .font(.headline)
                                .bold()
                            
                            Spacer()
                            
                            // Location
                            if let location = locationString, !location.isEmpty {
                                Text(location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            
                            if let updated = lastUpdated {
                                Text(updated, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        
                        // Temperature with metrics to the right
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(displayTemperature(temp))
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            
                            HStack(spacing: 8) {
                                Label(displayPressure(press), systemImage: "gauge.with.dots.needle.bottom.50percent")
                                Divider()
                                    .frame(height: 12)
                                Label(humid, systemImage: "humidity")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text(" Weather")
                            Text("•")
                                .accessibilityHidden(true)
                            Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                                .foregroundStyle(.red)
                            
                            Spacer()
                        }
                        .font(.caption)
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .onChange(of: userFacingErrorMessage(from: error)) { _, newMessage in
                    guard newMessage != nil else { return }
                    showErrorOverlay = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showErrorOverlay = false }
                    }
                }
                // Initialize previousCondition and optionally bounce on appear
                .onAppear {
                    if previousCondition == nil {
                        previousCondition = condition
                    }
                }
            } else {
                HStack(spacing: 15) {
                    Image(systemName: "location")
                        .font(.title)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weather Unavailable")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .allowsTightening(true)
                        Text(unavailableSubtitle(for: error))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Spacer()

                    if isFetching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
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


    // MARK: - Unit display helpers
    private func displayTemperature(_ raw: String) -> String {
        guard useMetricUnits else { return raw }
        // Try to parse a numeric value; assume Fahrenheit if no unit specified and value looks plausible
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Extract first number (including decimal)
        let numberString = trimmed.replacingOccurrences(of: ",(?=\\d)", with: "", options: .regularExpression)
        let regex = try! NSRegularExpression(pattern: "-?\\d+(?:\\.\\d+)?")
        let ns = numberString as NSString
        guard let match = regex.firstMatch(in: numberString, range: NSRange(location: 0, length: ns.length)) else { return raw }
        let val = Double(ns.substring(with: match.range)) ?? 0
        let isCelsius = trimmed.lowercased().contains("c")
        let isFahrenheit = trimmed.lowercased().contains("f") || !isCelsius // default to F when ambiguous
        if isFahrenheit {
            let c = (val - 32) * 5.0 / 9.0
            let rounded = Int((c).rounded())
            return "\(rounded)°"
        } else {
            // Already Celsius, return as-is (remove explicit unit if present to match design)
            return trimmed.replacingOccurrences(of: "°c", with: "°", options: .caseInsensitive)
        }
    }

    private func displayPressure(_ raw: String) -> String {
        guard useMetricUnits else { return raw }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Extract number
        let regex = try! NSRegularExpression(pattern: "-?\\d+(?:\\.\\d+)?")
        let ns = trimmed as NSString
        guard let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) else { return raw }
        let val = Double(ns.substring(with: match.range)) ?? 0
        if trimmed.lowercased().contains("inhg") {
            // inHg -> hPa
            let hpa = val * 33.8638866667
            let out = Int(hpa.rounded())
            return "\(out) hPa"
        } else if trimmed.lowercased().contains("mb") {
            // millibar ~ hPa
            let out = Int(val.rounded())
            return "\(out) hPa"
        } else if trimmed.lowercased().contains("hpa") {
            return trimmed // already metric
        } else {
            // Unknown unit; keep original
            return raw
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

