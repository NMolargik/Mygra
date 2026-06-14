//
//  WeatherCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation
import SwiftUI
import UIKit
import WeatherKit
import CoreLocation

struct WeatherCardView: View {
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    let temperature: Measurement<UnitTemperature>?
    let pressure: Measurement<UnitPressure>?
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
            if let temp = temperature,
               let press = pressure,
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
                            Text(formattedTemperature(temp))
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            
                            HStack(spacing: 8) {
                                Label(formattedPressure(press), systemImage: "gauge.with.dots.needle.bottom.50percent")
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
                                .foregroundStyle(.mygraPurple)
                                .accessibilityLabel("Apple Weather legal attribution, opens in browser")
                            
                            Spacer()
                        }
                        .font(.caption)
                    }
                }
                .cardStyle()
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
                    Task {
                        try? await Task.sleep(for: .seconds(2))
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
                    Image(systemName: "location.slash")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)

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
                            .tint(.mygraPurple)
                            .accessibilityLabel("Loading weather data")
                    } else {
                        HStack(spacing: 8) {
                            if isLocationPermissionError {
                                Button(action: openAppSettings) {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                .glassActionButton(prominent: false)
                                .accessibilityLabel("Open location settings")
                            }

                            Button(action: onRefresh) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                            }
                            .glassActionButton(prominent: false)
                            .accessibilityLabel("Refresh weather data")
                        }
                    }
                }
                .cardStyle()
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
                return "Weather data isn't available yet. Try refreshing."
            }
        }
        if error.domain == NSURLErrorDomain {
            return "Network issue. Check your connection and try again."
        }
        return "Weather data isn't available yet. Try refreshing."
    }

    private var isLocationPermissionError: Bool {
        guard let error = error as NSError? else { return false }
        guard error.domain == kCLErrorDomain as String else { return false }
        switch CLError.Code(rawValue: error.code) {
        case .some(.denied), .some(.promptDeclined):
            return true
        default:
            return false
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }


    // MARK: - Unit display helpers

    /// Formats the temperature for the user's unit preference, e.g. "78°".
    private func formattedTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let converted = measurement.converted(to: useMetricUnits ? .celsius : .fahrenheit)
        return "\(Int(converted.value.rounded()))°"
    }

    /// Formats the pressure for the user's unit preference, e.g. "1013 hPa" or "29.92 inHg".
    private func formattedPressure(_ measurement: Measurement<UnitPressure>) -> String {
        if useMetricUnits {
            let hpa = measurement.converted(to: .hectopascals).value
            return "\(Int(hpa.rounded())) hPa"
        } else {
            let inhg = measurement.converted(to: .inchesOfMercury).value
            return String(format: "%.2f inHg", inhg)
        }
    }
}

// MARK: - Previews

#Preview("Sunny in Indy") {
    WeatherCardView(
        temperature: Measurement(value: 78, unit: .fahrenheit),
        pressure: Measurement(value: 29.9, unit: .inchesOfMercury),
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
        temperature: Measurement(value: 78, unit: .fahrenheit),
        pressure: Measurement(value: 29.9, unit: .inchesOfMercury),
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
        temperature: nil,
        pressure: nil,
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

