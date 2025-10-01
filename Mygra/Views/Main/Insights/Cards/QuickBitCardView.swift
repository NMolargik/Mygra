//
//  QuickBitCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct QuickBitsSectionView: View {
    @Environment(InsightManager.self) private var insightManager: InsightManager
    @AppStorage(AppStorageKeys.useMetricUnits) var useMetricUnits: Bool = false
    
    let insights: [Insight]
    let isRefreshing: Bool
    let errors: [Error]
    let onRefresh: () -> Void
    
    @State private var expandedIDs: Set<String> = []
    @State private var loadingIDs: Set<String> = []
    @State private var explanations: [String: QuickBitExplanation] = [:]

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
                        let key = insight.dedupeKey.key
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowView(
                                style: .insight,
                                systemImage: iconName(for: insight.category),
                                title: insight.title,
                                subtitle: displayMessage(for: insight),
                                tint: color(for: insight.priority)
                            ) {
                                priorityBadge(for: insight.priority)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.lightImpact()
                                let isExpanded = expandedIDs.contains(key)
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                    if isExpanded {
                                        expandedIDs.remove(key)
                                    } else {
                                        expandedIDs.insert(key)
                                    }
                                }
                                if !isExpanded {
                                    // Load explanation when expanding
                                    if explanations[key] == nil && !loadingIDs.contains(key) {
                                        loadingIDs.insert(key)
                                        Task {
                                            var fetched: QuickBitExplanation?
                                            if #available(iOS 26.0, *), insightManager.intelligenceManager.supportsAppleIntelligence {
                                                fetched = await insightManager.explanation(for: insight)
                                            }
                                            await MainActor.run {
                                                withAnimation(.easeInOut) {
                                                    if let exp = fetched {
                                                        explanations[key] = exp
                                                    }
                                                    loadingIDs.remove(key)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if expandedIDs.contains(key) {
                                if loadingIDs.contains(key) || explanations[key] != nil {
                                    QuickBitExplanationBubble(
                                        isLoading: loadingIDs.contains(key),
                                        explanation: explanations[key],
                                        tint: color(for: insight.priority)
                                    )
                                }
                            }
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

private struct QuickBitExplanationBubble: View {
    let isLoading: Bool
    let explanation: QuickBitExplanation?
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer()

            Image(systemName: "arrow.turn.down.right")
                .foregroundStyle(tint)
                .padding([.top, .leading], 5)

            Group {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(tint)

                        Text("Generating explanation…")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if let exp = explanation {
                    VStack(alignment: .leading, spacing: 8) {
                        if !exp.description.isEmpty {
                            Text(exp.description)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !exp.recommendation.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.mygraPurple)
                                Text(exp.recommendation)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))

                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
