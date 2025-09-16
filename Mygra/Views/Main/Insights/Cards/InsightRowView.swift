//
//  InsightRowView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct InsightRowView: View {
    let insight: Insight
    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: insight.category))
                .foregroundStyle(color(for: insight.priority).gradient)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline).bold()
                Text(displayMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                priorityBadge(insight.priority)
                Spacer()
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
