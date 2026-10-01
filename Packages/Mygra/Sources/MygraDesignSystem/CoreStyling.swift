//
//  CoreStyling.swift
//  MygraDesignSystem
//
//  SwiftUI-facing styling for Core enums and models (Core stays SwiftUI-free).
//

import SwiftUI
import MygraCore

extension Severity {
    public var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

extension AppTab {
    public func icon() -> Image {
        switch self {
        case .dashboard: return Image(systemName: "square.grid.2x2.fill")
        case .calendar: return Image(systemName: "calendar")
        case .list: return Image(systemName: "list.bullet")
        case .settings: return Image(systemName: "gearshape.2")
        }
    }

    public func color() -> Color {
        switch self {
        case .dashboard: return .pink
        case .calendar: return .mygraPurple
        case .list: return .mygraBlue
        case .settings: return .orange
        }
    }
}

extension DashboardStat {
    public var color: Color {
        switch self {
        case .water: return .blue
        case .sleep: return .indigo
        case .food: return .orange
        case .caffeine: return .brown
        case .steps: return .green
        case .restingHeartRate: return .red
        case .bloodOxygen: return .cyan
        case .bloodGlucose: return .mint
        case .topTriggers: return .purple
        }
    }
}

extension InsightPriority {
    public var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

extension InsightCategory {
    public var systemImage: String {
        switch self {
        case .trendFrequency: return "chart.line.uptrend.xyaxis"
        case .trendSeverity: return "waveform.path.ecg"
        case .trendDuration: return "clock"
        case .triggers: return "exclamationmark.octagon.fill"
        case .foods: return "fork.knife"
        case .intakeHydration: return "drop.fill"
        case .intakeSleep: return "bed.double.fill"
        case .intakeNutrition: return "fork.knife"
        case .sleepAssociation: return "zzz"
        case .weatherAssociation: return "cloud.sun"
        case .generative: return "sparkles"
        case .biometrics: return "waveform.path.ecg.text.clipboard"
        case .intensityPattern: return "chart.xyaxis.line"
        case .intensityPeakTiming: return "timer"
        case .tagFrequency: return "tag.fill"
        case .tagSeverityCorrelation: return "tag.circle.fill"
        }
    }
}

extension MenstrualPhase {
    public var systemImage: String {
        switch self {
        case .menstrual: return "drop.circle.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory: return "sparkles"
        case .luteal: return "circle.lefthalf.filled"
        }
    }

    public var color: Color {
        switch self {
        case .menstrual: return .pink
        case .follicular: return .green
        case .ovulatory: return .yellow
        case .luteal: return .orange
        }
    }
}

extension MigraineTag {
    /// The SwiftUI color for the persisted hex.
    public var color: Color {
        Color(hex: colorHex) ?? .purple
    }
}

extension SkyCondition {
    /// SF Symbol name representing this condition.
    public var symbolName: String {
        switch self {
        case .clear, .mostlyClear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy: return "cloud.fill"
        case .drizzle, .rain, .freezingDrizzle, .sunShowers: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .strongStorms, .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .tropicalStorm, .hurricane: return "cloud.bolt.rain.fill"
        case .snow, .flurries, .heavySnow, .sunFlurries: return "cloud.snow.fill"
        case .sleet, .freezingRain, .wintryMix, .hail: return "cloud.sleet.fill"
        case .haze, .foggy: return "cloud.fog.fill"
        case .windy, .breezy: return "wind"
        case .blowingSnow, .blizzard: return "wind.snow"
        case .blowingDust: return "sun.dust.fill"
        case .frigid: return "thermometer.snowflake"
        case .hot: return "thermometer.sun.fill"
        case .smoky: return "smoke.fill"
        }
    }

    /// Palette colors layered onto the symbol, ordered by layer.
    public var symbolColors: (layer1: Color, layer2: Color) {
        switch self {
        case .clear, .mostlyClear: return (.yellow, .yellow)
        case .partlyCloudy: return (.gray, .yellow)
        case .cloudy, .mostlyCloudy: return (.gray, .gray)
        case .drizzle, .rain, .freezingDrizzle, .sunShowers: return (.gray, .blue)
        case .heavyRain: return (.gray, Color.blue.opacity(0.9))
        case .strongStorms, .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .tropicalStorm, .hurricane: return (.gray, .indigo)
        case .snow, .flurries, .heavySnow, .sunFlurries: return (.gray, .cyan)
        case .sleet, .freezingRain, .wintryMix, .hail: return (.gray, .teal)
        case .haze, .foggy: return (.gray, .gray.opacity(0.6))
        case .windy, .breezy: return (.teal, .teal)
        case .blowingSnow, .blizzard: return (.gray, .cyan)
        case .blowingDust: return (.orange, .brown)
        case .frigid: return (.blue, .blue)
        case .hot: return (.red, .orange)
        case .smoky: return (.brown, .brown)
        }
    }

    /// Ready-to-use palette symbol view. Apply font/effects at the call site.
    public func symbolView() -> some View {
        let colors = symbolColors
        return Image(systemName: symbolName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(colors.layer1.gradient, colors.layer2.gradient)
    }
}
