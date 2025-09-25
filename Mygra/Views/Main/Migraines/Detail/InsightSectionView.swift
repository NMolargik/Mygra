//
//  InsightSectionView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct InsightSectionView: View {
    @Environment(InsightManager.self) private var insightManager: InsightManager
    let migraine: Migraine
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Group {
                    let isGenerating = insightManager.isGeneratingGuidance && insightManager.isGeneratingGuidanceFor?.id == migraine.id
                    if isGenerating || (migraine.insight?.isEmpty == false) {
                        InfoDetailView(title: "Insight") {
                            VStack(alignment: .leading, spacing: 8) {
                                // Header row indicating Apple Intelligence
                                HStack(spacing: 6) {
                                    Image(systemName: "apple.intelligence")
                                        .foregroundStyle(
                                            AngularGradient(
                                                colors: [.orange, .red, .purple, .blue, .purple, .red, .orange, .orange],
                                                center: .center,
                                                startAngle: .degrees(-90),
                                                endAngle: .degrees(270)
                                            )
                                        )
                                    Text("Powered by Apple Intelligence")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if isGenerating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                                
                                if isGenerating && (migraine.insight?.isEmpty ?? true) {
                                    // Loading placeholder while generating
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Generating insight…")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        // Subtle animated placeholder lines
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
                                }
                            }
                        }
                    }
                }
            } else {
                IntelligenceUpgradeCardView()
            }
        }
    }
}

#Preview {
    InsightSectionView(migraine: Migraine(startDate: Date.now, painLevel: 5, stressLevel: 4))
}
