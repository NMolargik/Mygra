//
//  IntelligenceUpgradeCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/23/25.
//

import SwiftUI
import UIKit

struct IntelligenceUpgradeCardView: View {
    private var platformName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS 26" : "iOS 26"
    }
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(.red)

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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Intelligence. Update to \(platformName) to access these features.")
    }
}


#Preview {
    IntelligenceUpgradeCardView()
}

