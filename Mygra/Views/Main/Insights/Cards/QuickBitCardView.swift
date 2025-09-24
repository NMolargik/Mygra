//
//  QuickBitCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct QuickBitsSectionView: View {
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
                    .foregroundStyle(.red)
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
                        InsightRowView(insight: insight)
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

#Preview("Empty") {
    QuickBitsSectionView(
        insights: [],
        isRefreshing: false,
        errors: [],
        onRefresh: {}
    )
    .padding()
}

#Preview("Refreshing") {
    QuickBitsSectionView(
        insights: [],
        isRefreshing: true,
        errors: [],
        onRefresh: {}
    )
    .padding()
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
    .padding()
}
