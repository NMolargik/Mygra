//
//  QuickBitsSectionView.swift
//  MygraFeatureDashboard
//
//  The rule-based insights list with expandable Apple Intelligence explanations.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct QuickBitsSectionView: View {
    @Environment(InsightModel.self) private var insights
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    let onRefresh: () -> Void

    @State private var expandedKeys: Set<String> = []
    @State private var loadingKeys: Set<String> = []
    @State private var explanations: [String: QuickBitExplanation] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Quick Bits", systemImage: "lightbulb.max.fill")
                    .font(.headline)
                Spacer()
                if insights.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading insights")
                } else {
                    Button(action: onRefresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.mygraPurple)
                    .accessibilityLabel("Refresh insights")
                }
            }
            .padding(.bottom, 8)

            if insights.insights.isEmpty {
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
                LazyVStack(spacing: 10) {
                    ForEach(insights.insights.prefix(8)) { insight in
                        let key = insight.dedupeKey.key
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowView(
                                style: .insight,
                                systemImage: insight.category.systemImage,
                                title: insight.title,
                                subtitle: displayMessage(for: insight),
                                tint: insight.priority.color
                            ) {
                                priorityBadge(insight.priority)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(insight, key: key) }
                            .hoverLift()
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint(expandedKeys.contains(key) ? "Collapses the explanation" : "Explains this insight with Apple Intelligence")

                            if expandedKeys.contains(key), loadingKeys.contains(key) || explanations[key] != nil {
                                QuickBitExplanationBubble(
                                    isLoading: loadingKeys.contains(key),
                                    explanation: explanations[key],
                                    tint: insight.priority.color
                                )
                            }
                        }
                    }
                }
            }

            ForEach(Array(insights.errors.enumerated()), id: \.offset) { _, failure in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    Text(failure.errorDescription ?? "").font(.footnote)
                    Spacer()
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .cardSurface()
    }

    private func toggle(_ insight: Insight, key: String) {
        Haptics.lightImpact()
        let isExpanded = expandedKeys.contains(key)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            if isExpanded {
                expandedKeys.remove(key)
            } else {
                expandedKeys.insert(key)
            }
        }
        guard !isExpanded, explanations[key] == nil, !loadingKeys.contains(key) else { return }
        loadingKeys.insert(key)
        Task {
            let fetched = await insights.explanation(for: insight)
            withAnimation(.easeInOut) {
                if let fetched { explanations[key] = fetched }
                loadingKeys.remove(key)
            }
        }
    }

    private func priorityBadge(_ priority: InsightPriority) -> some View {
        Text(priority.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.15), in: Capsule())
            .foregroundStyle(priority.color)
    }

    /// Hydration insights are re-rendered in the user's units.
    private func displayMessage(for insight: Insight) -> String {
        guard insight.category == .intakeHydration, let liters = insight.doubleTag("avgLiters") else {
            return insight.message
        }
        if useMetricUnits {
            return String(format: String(localized: "Average water intake: %.1f L on migraine days."), liters)
        }
        let ounces = (liters * UnitConversion.litersToFluidOunces).rounded()
        return String(format: String(localized: "Average water intake: %.0f fl oz on migraine days."), ounces)
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
                } else if let explanation {
                    VStack(alignment: .leading, spacing: 8) {
                        if !explanation.description.isEmpty {
                            Text(explanation.description)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !explanation.recommendation.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.mygraPurple)
                                Text(explanation.recommendation)
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

#if DEBUG
#Preview {
    QuickBitsSectionView(onRefresh: {})
        .padding()
        .previewEnvironment()
}
#endif
#endif
