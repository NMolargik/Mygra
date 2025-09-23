//
//  IntelligenceUpgradeCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/23/25.
//

import SwiftUI

struct IntelligenceUpgradeCardView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Intelligence")
                    .font(.headline)
                    .bold()
                Text("Update to iOS 26 to use the Migraine Assistant and AI‑powered Insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .layoutPriority(1)

            Spacer()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Intelligence. Update to iOS 26 to access these features.")
    }
}


#Preview {
    IntelligenceUpgradeCardView()
}
