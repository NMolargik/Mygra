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
    
    @State private var animateHeaderGlow = false
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Group {
                    let isGenerating = insightManager.isGeneratingGuidance && insightManager.isGeneratingGuidanceFor?.id == migraine.id
                    let hasInsight = (migraine.insight?.isEmpty == false)
                    if isGenerating || hasInsight {
                        InfoDetailView(title: "Insight", trailing: {
                            HStack(spacing: 6) {
                                Image(systemName: "apple.intelligence")
                                    .symbolEffect(.pulse, isActive: isGenerating)
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
                                    .overlay {
                                        LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                                            .mask(
                                                Text("Powered by Apple Intelligence").font(.caption)
                                            )
                                            .opacity(animateHeaderGlow ? 1 : 0.2)
                                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateHeaderGlow)
                                    }
                                if isGenerating {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                AngularGradient(
                                                    colors: [.orange.opacity(0.9), .pink.opacity(0.8), .purple.opacity(0.9), .blue.opacity(0.9), .purple.opacity(0.9), .pink.opacity(0.8), .orange.opacity(0.9)],
                                                    center: .center
                                                ),
                                                lineWidth: 1
                                            )
                                            .opacity(0.9)
                                    )
                                    .shadow(color: .purple.opacity(0.15), radius: 8, x: 0, y: 2)
                            )
                        }) {
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
                                    .contentTransition(.opacity)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .sensoryFeedback(.success, trigger: hasInsight && !isGenerating)
                        .onAppear { animateHeaderGlow = true }
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
