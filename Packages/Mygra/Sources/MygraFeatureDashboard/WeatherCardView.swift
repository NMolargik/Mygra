//
//  WeatherCardView.swift
//  MygraFeatureDashboard
//

#if os(iOS)
import SwiftUI
import CoreLocation
import MygraCore
import MygraDesignSystem
import MygraServices

struct WeatherCardView: View {
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    let reading: WeatherReading?
    let isFetching: Bool
    let error: (any Error)?
    let locationString: String?
    let onRefresh: () -> Void

    @State private var bounceFlag = false

    var body: some View {
        Group {
            if let reading {
                readingCard(reading)
            } else {
                unavailableCard
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func readingCard(_ reading: WeatherReading) -> some View {
        HStack(spacing: 15) {
            reading.condition.symbolView()
                .font(.title)
                .symbolEffect(.bounce, options: .repeat(1), value: bounceFlag)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.condition.displayName)
                        .font(.headline)
                        .bold()
                    Spacer()
                    if let locationString, !locationString.isEmpty {
                        Text(locationString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text(reading.fetchedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(reading.formattedTemperature(useMetricUnits: useMetricUnits))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    HStack(spacing: 8) {
                        Label(reading.formattedPressure(useMetricUnits: useMetricUnits), systemImage: "gauge.with.dots.needle.bottom.50percent")
                        Divider().frame(height: 12)
                        Label(reading.formattedHumidity, systemImage: "humidity")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                WeatherAttributionView()
                    .font(.caption)
            }
        }
        .cardStyle()
        .onChange(of: reading.condition) { bounceFlag.toggle() }
        .onAppear { bounceFlag.toggle() }
    }

    private var unavailableCard: some View {
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
                Text(unavailableSubtitle)
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

    // MARK: - Error presentation

    private var unavailableSubtitle: String {
        guard let error = error as NSError? else {
            return String(localized: "Enable location and refresh to see current weather.")
        }
        if error.domain == kCLErrorDomain {
            switch CLError.Code(rawValue: error.code) {
            case .denied, .promptDeclined:
                return String(localized: "Location access is needed to show local weather.")
            case .network:
                return String(localized: "Network issue. Check your connection and try again.")
            default:
                break
            }
        }
        if error.domain == NSURLErrorDomain {
            return String(localized: "Network issue. Check your connection and try again.")
        }
        if let weatherError = self.error as? WeatherError, case .locationUnavailable = weatherError {
            return String(localized: "Location access is needed to show local weather.")
        }
        return String(localized: "Weather data isn't available yet. Try refreshing.")
    }

    private var isLocationPermissionError: Bool {
        if let weatherError = error as? WeatherError, case .locationUnavailable = weatherError { return true }
        guard let error = error as NSError?, error.domain == kCLErrorDomain else { return false }
        switch CLError.Code(rawValue: error.code) {
        case .denied, .promptDeclined: return true
        default: return false
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Sunny") {
    WeatherCardView(
        reading: WeatherReading(temperature: Measurement(value: 78, unit: .fahrenheit), pressure: Measurement(value: 29.9, unit: .inchesOfMercury), humidity: 0.45, condition: .clear, fetchedAt: Date()),
        isFetching: false,
        error: nil,
        locationString: "Indianapolis, IN",
        onRefresh: {}
    )
    .padding()
}

#Preview("Unavailable") {
    WeatherCardView(
        reading: nil,
        isFetching: false,
        error: NSError(domain: NSURLErrorDomain, code: -1009),
        locationString: nil,
        onRefresh: {}
    )
    .padding()
}
#endif
