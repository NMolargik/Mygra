//
//  DetailSections.swift
//  MygraFeatureMigraines
//
//  The read-only sections of the migraine detail screen: note, triggers, weather, health.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct NoteDetailView: View {
    let note: String

    var body: some View {
        InfoDetailView(title: String(localized: "Note")) {
            Text(note)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TriggersDetailView: View {
    let triggers: [MigraineTrigger]
    let customTriggers: [String]

    var body: some View {
        InfoDetailView(title: String(localized: "Triggers")) {
            TriggerChipFlow(labels: triggers.map(\.displayName) + customTriggers)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Trigger names as wrapping chips, so a long list reads at a glance.
private struct TriggerChipFlow: View {
    let labels: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Brand.Space.sm, alignment: .leading)], alignment: .leading, spacing: Brand.Space.sm) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .padding(.horizontal, Brand.Space.md)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color.mygraPurple.opacity(0.14)))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Triggers: \(labels.joined(separator: ", "))"))
    }
}

struct WeatherDetailView: View {
    let weather: WeatherData
    let useMetricUnits: Bool

    var body: some View {
        InfoDetailView(title: String(localized: "Weather"), trailing: {
            WeatherAttributionView()
                .font(.caption2)
                .foregroundStyle(.secondary)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                if let place = weather.locationDescription, !place.isEmpty {
                    MetricRowView(String(localized: "Location")) {
                        MetricChip(place, systemImage: "location.fill", tint: .blue)
                    }
                }
                MetricRowView(String(localized: "Condition")) {
                    HStack(spacing: 8) {
                        Text(weather.condition.displayName)
                            .font(.callout).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule(style: .continuous).fill(Color.secondary.opacity(0.14)))
                        weather.condition.symbolView()
                            .frame(width: 30)
                    }
                }
                MetricRowView(String(localized: "Temperature")) {
                    let temp = weather.displayTemperature(useMetricUnits: useMetricUnits)
                    MetricChip("\(Int(temp.rounded())) \(useMetricUnits ? "°C" : "°F")", systemImage: "thermometer.medium", tint: .red)
                }
                MetricRowView(String(localized: "Humidity")) {
                    MetricChip("\(Int(weather.humidityPercent))%", systemImage: "humidity.fill", tint: .blue)
                }
                MetricRowView(String(localized: "Pressure")) {
                    let pressure = weather.displayBarometricPressure(useMetricUnits: useMetricUnits)
                    let text = useMetricUnits ? String(format: "%.0f hPa", pressure) : String(format: "%.2f inHg", pressure)
                    MetricChip(text, systemImage: "gauge.medium", tint: .teal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HealthDetailView: View {
    let health: HealthData
    let useMetricUnits: Bool

    var body: some View {
        InfoDetailView(title: String(localized: "Health")) {
            VStack(alignment: .leading, spacing: 8) {
                if let water = health.waterLiters {
                    MetricRowView(String(localized: "Water")) {
                        let text = useMetricUnits
                            ? String(format: "%.1f L", water)
                            : String(format: "%.0f fl oz", water * UnitConversion.litersToFluidOunces)
                        MetricChip(text, systemImage: "drop.fill", tint: .blue)
                    }
                }
                if let sleep = health.sleepHours {
                    MetricRowView(String(localized: "Sleep")) {
                        MetricChip(String(format: "%.1f h", sleep), systemImage: "bed.double.fill", tint: .indigo)
                    }
                }
                if let kcal = health.energyKilocalories {
                    MetricRowView(String(localized: "Food")) {
                        MetricChip(String(format: "%.0f cal", kcal), systemImage: "fork.knife", tint: .orange)
                    }
                }
                if let caffeine = health.caffeineMg {
                    MetricRowView(String(localized: "Caffeine")) {
                        MetricChip(String(format: "%.0f mg", caffeine), systemImage: "cup.and.saucer.fill", tint: .brown)
                    }
                }
                if let steps = health.stepCount {
                    MetricRowView(String(localized: "Steps")) {
                        MetricChip("\(steps)", systemImage: "figure.walk", tint: .green)
                    }
                }
                if let rhr = health.restingHeartRate {
                    MetricRowView(String(localized: "Resting HR")) {
                        MetricChip("\(rhr) bpm", systemImage: "heart.fill", tint: .red)
                    }
                }
                if let ahr = health.activeHeartRate {
                    MetricRowView(String(localized: "Active HR")) {
                        MetricChip("\(ahr) bpm", systemImage: "bolt.heart.fill", tint: .pink)
                    }
                }
                if let phase = health.menstrualPhase {
                    MetricRowView(String(localized: "Menstrual Phase")) {
                        MetricChip(phase.displayName, systemImage: "drop.triangle.fill", tint: .purple)
                    }
                }
                if let glucose = health.glucoseMgPerdL {
                    MetricRowView(String(localized: "Glucose")) {
                        let text = useMetricUnits
                            ? String(format: "%.1f mmol/L", glucose / UnitConversion.glucoseMgDlToMmolL)
                            : String(format: "%.0f mg/dL", glucose.rounded())
                        MetricChip(text, systemImage: "cross.case.fill", tint: .mint)
                    }
                }
                if let spo2 = health.bloodOxygenPercent {
                    let percent = spo2 * 100.0
                    MetricRowView(String(localized: "Oxygen Saturation")) {
                        let text = percent.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(percent))%" : String(format: "%.1f%%", percent)
                        MetricChip(text, systemImage: "lungs.fill", tint: .cyan)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            NoteDetailView(note: "Flickering lights and skipped lunch.")
            TriggersDetailView(triggers: [.stress], customTriggers: ["Bright lights"])
            WeatherDetailView(weather: WeatherData(barometricPressureHpa: 1008, temperatureCelsius: 22, humidityPercent: 65, condition: .partlyCloudy, locationDescription: "Seattle, WA"), useMetricUnits: false)
            HealthDetailView(health: HealthData(waterLiters: 1.2, sleepHours: 6.5, caffeineMg: 120, bloodOxygenPercent: 0.97), useMetricUnits: false)
        }
        .padding()
    }
}
#endif
#endif
