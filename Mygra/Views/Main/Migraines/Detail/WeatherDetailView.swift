//
//  WeatherDetailView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//


import SwiftUI
import WeatherKit

struct WeatherDetailView: View {
    let weather: WeatherData
    let useMetricUnits: Bool
    
    var body: some View {
        InfoDetailView(title: "Weather", trailing: {
            HStack(spacing: 6) {
                Text(" Weather")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("•")
                    .accessibilityHidden(true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                if let place = weather.locationDescription, !place.isEmpty {
                    LabeledRow("Location", value: place)
                }
                
                LabeledRow("Condition") {
                    HStack(spacing: 8) {
                        weather.condition.mygraSymbolView()
                        Text(weather.condition.description)
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.secondary.opacity(0.14))
                            )
                    }
                }
                
                LabeledRow("Temperature") {
                    let temp = weather.displayTemperature(useMetricUnits: useMetricUnits)
                    let unit = useMetricUnits ? "°C" : "°F"
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .foregroundStyle(.red)
                        Text("\(Int(round(temp))) \(unit)")
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.red.opacity(0.14))
                            )
                    }
                }
                
                LabeledRow("Humidity") {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.blue)
                        Text("\(Int(weather.humidityPercent))%")
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.blue.opacity(0.14))
                            )
                    }
                }
                
                LabeledRow("Pressure") {
                    let pressure = weather.displayBarometricPressure(useMetricUnits: useMetricUnits)
                    HStack(spacing: 8) {
                        Image(systemName: "gauge.medium")
                            .foregroundStyle(.teal)
                        Group {
                            if useMetricUnits {
                                Text(String(format: "%.0f hPa", pressure))
                            } else {
                                Text(String(format: "%.2f inHg", pressure))
                            }
                        }
                        .font(.callout).bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.teal.opacity(0.14))
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    WeatherDetailView(weather: WeatherData(), useMetricUnits: false)
}
