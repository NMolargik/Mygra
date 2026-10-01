//
//  InsightSectionView.swift
//  MygraFeatureMigraines
//
//  The Apple Intelligence explanation for one migraine (or the upgrade card).
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct InsightSectionView: View {
    @Environment(InsightModel.self) private var insights
    let migraine: Migraine

    private var isGenerating: Bool {
        insights.isGeneratingGuidance && insights.generatingGuidanceForID == migraine.id
    }

    private var hasInsight: Bool { migraine.insight?.isEmpty == false }

    var body: some View {
        if #available(iOS 26.0, *) {
            if isGenerating || hasInsight {
                InfoDetailView(title: String(localized: "Insight"), trailing: {
                    AppleIntelligenceBadge(isGenerating: isGenerating)
                }) {
                    if isGenerating && !hasInsight {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Generating insight…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 10)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(width: 220, height: 10)
                            }
                            .redacted(reason: .placeholder)
                            .shimmer()
                        }
                    } else if let text = migraine.insight, !text.isEmpty {
                        Text(text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentTransition(.opacity)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .sensoryFeedback(.success, trigger: hasInsight && !isGenerating)
            }
        } else {
            IntelligenceUpgradeNotice()
        }
    }
}

/// Shown on releases before Apple Intelligence.
struct IntelligenceUpgradeNotice: View {
    private var platformName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS 26" : "iOS 26"
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Intelligence")
                    .font(.headline)
                    .bold()
                Text("Update to \(platformName) to use the Migraine Assistant and AI‑powered Insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .layoutPriority(1)
            Spacer()
        }
        .padding(14)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Intelligence. Update to \(platformName) to access these features.")
    }
}

#Preview {
    InsightSectionView(migraine: Migraine.sample())
        .padding()
        .previewEnvironment()
}
#endif
