//
//  WeatherCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation
import SwiftUI
import WeatherKit

struct WeatherCardView: View {
    let temperatureString: String?
    let pressureString: String?
    let humidityPercentString: String?
    let condition: WeatherCondition?
    let lastUpdated: Date?
    let isFetching: Bool
    let error: Error?
    let onRefresh: () -> Void
    // NEW: Optional location display (e.g., "San Francisco, CA")
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
                    Image(systemName: symbolName(for: condition))
                        .font(.system(size: 32))
                        .foregroundStyle(symbolColor(for: condition))
                        // Apply bounce when bounceFlag toggles
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
                    if let error {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                                Text(error.localizedDescription).font(.footnote)
                                Spacer()
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(6)
                        }
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
                        Text("Enable location and refresh to see current weather.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

    private func symbolColor(for condition: WeatherCondition) -> Color {
        switch condition {
        case .clear, .mostlyClear: return .yellow
        case .partlyCloudy: return .orange
        case .cloudy, .mostlyCloudy: return .gray
        case .drizzle, .rain: return .blue
        case .heavyRain: return Color.blue.opacity(0.9)
        case .strongStorms: return .indigo
        case .snow, .flurries: return .cyan
        case .sleet, .freezingRain: return .teal
        case .haze, .foggy: return .gray.opacity(0.7)
        case .windy: return .teal
        case .blowingSnow, .blizzard: return .cyan
        case .frigid: return .blue
        case .hot: return .red
        case .smoky: return .brown
        default: return .gray
        }
    }
}
