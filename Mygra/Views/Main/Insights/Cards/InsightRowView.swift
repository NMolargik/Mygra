//
//  InsightRowView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct InsightRowView: View {
    let insight: Insight
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color(for: insight.priority).opacity(0.12))
                Image(systemName: iconName(for: insight.category))
                    .symbolVariant(.fill)
                    .foregroundStyle(color(for: insight.priority))
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline).bold()
                    .minimumScaleFactor(0.9)
                Text(displayMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                priorityBadge(insight.priority)
                Spacer()
            }
        }
        .padding(12)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Display overrides for unit-aware content

    private var displayMessage: String {
        switch insight.category {
        case .intakeHydration:
            // Expect tag "avgLiters": Double
            if let any = insight.tags["avgLiters"],
               let liters = any as? Double {
                if useMetricUnits {
                    return String(format: "Average water intake: %.1f L on migraine days.", liters)
                } else {
                    let flOz = liters * 33.8140227
                    return String(format: "Average water intake: %.0f fl oz on migraine days.", flOz.rounded())
                }
            }
            return insight.message

        default:
            return insight.message
        }
    }

    // MARK: - UI helpers (unchanged)

    private func priorityBadge(_ priority: InsightPriority) -> some View {
        Text(priorityLabel(priority))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: priority).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: priority))
    }

    private func color(for priority: InsightPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func priorityLabel(_ priority: InsightPriority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private func iconName(for category: InsightCategory) -> String {
        switch category {
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
        }
    }
}

#Preview("Hydration – Metric") {
    // Ensure AppStorage-backed units default to metric for this preview
    UserDefaults.standard.register(defaults: [
        AppStorageKeys.useMetricUnits: true
    ])

    let hydrationInsight = Insight(
        category: .intakeHydration,
        title: "Low hydration on migraine days",
        message: "Average water intake: 1.1 L on migraine days.",
        priority: .high,
        tags: ["avgLiters": 1.1]
    )

    return InsightRowView(insight: hydrationInsight)
        .padding()
}

#Preview("Hydration – Imperial") {
    // Ensure AppStorage-backed units default to imperial for this preview
    UserDefaults.standard.register(defaults: [
        AppStorageKeys.useMetricUnits: false
    ])

    let hydrationInsight = Insight(
        category: .intakeHydration,
        title: "Low hydration on migraine days",
        message: "Average water intake: 37 fl oz on migraine days.",
        priority: .medium,
        tags: ["avgLiters": 1.1]
    )

    return InsightRowView(insight: hydrationInsight)
        .padding()
}

#Preview("Trigger – Medium Priority") {
    let triggerInsight = Insight(
        category: .triggers,
        title: "Common trigger: Screen time",
        message: "53% of migraines included Screen time",
        priority: .medium
    )

    return InsightRowView(insight: triggerInsight)
        .padding()
}
