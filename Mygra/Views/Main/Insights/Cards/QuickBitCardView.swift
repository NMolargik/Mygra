//
//  QuickBitCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct QuickBitsSectionView: View {
    @AppStorage(AppStorageKeys.useMetricUnits) var useMetricUnits: Bool = false
    
    let insights: [Insight]
    let isRefreshing: Bool
    let errors: [Error]
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Quick Bits", systemImage: "lightbulb.max.fill")
                    .font(.headline)
                Spacer()
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.mygraPurple)
                }
            }
            .padding(.bottom, 8)

            if insights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No insights yet")
                        .font(.subheadline).bold()
                    Text("Log migraines and connect Health & Weather to see trends and associations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                let top = Array(insights.prefix(8))
                LazyVStack(spacing: 10) {
                    ForEach(top) { insight in
                        DetailRowView(
                            style: .insight,
                            systemImage: iconName(for: insight.category),
                            title: insight.title,
                            subtitle: displayMessage(for: insight),
                            tint: color(for: insight.priority)
                        ) {
                            priorityBadge(for: insight.priority)
                        }
                    }
                }
            }

            if !errors.isEmpty {
                ForEach(Array(errors.enumerated()), id: \.offset) { _, err in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text(err.localizedDescription).font(.footnote)
                        Spacer()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension QuickBitsSectionView {
    func priorityBadge(for priority: InsightPriority) -> some View {
        Text(priorityLabel(priority))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: priority).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: priority))
    }

    func color(for priority: InsightPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    func priorityLabel(_ priority: InsightPriority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    func iconName(for category: InsightCategory) -> String {
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

    func displayMessage(for insight: Insight) -> String {
        switch insight.category {
        case .intakeHydration:
            if let any = insight.tags["avgLiters"], let liters = any as? Double {
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
}

#Preview("Empty") {
    QuickBitsSectionView(
        insights: [],
        isRefreshing: false,
        errors: [],
        onRefresh: {}
    )
}

#Preview("Refreshing") {
    QuickBitsSectionView(
        insights: [],
        isRefreshing: true,
        errors: [],
        onRefresh: {}
    )
}

#Preview("With Error Banner") {
    let sampleError = NSError(
        domain: "Preview",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to fetch latest insights. Please try again."]
    ) as Error

    return QuickBitsSectionView(
        insights: [],
        isRefreshing: false,
        errors: [sampleError],
        onRefresh: {}
    )
}
