//
//  IntelligenceCardView.swift
//  MygraFeatureDashboard
//
//  The Migraine Assistant entry card (and the upgrade card for older releases).
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

struct IntelligenceCardView: View {
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            AppleIntelligenceSymbol()
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text("Migraine Assistant")
                    .font(.headline)
                Text("Get personalized guidance powered by Apple Intelligence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onOpen) {
                Label("Chat", systemImage: "sparkles")
            }
            .glassActionButton(tint: .mygraPurple)
            .hoverHighlight()
            .accessibilityLabel("Open Migraine Assistant")
        }
        .padding(16)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

struct IntelligenceUpgradeCardView: View {
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
    VStack {
        IntelligenceCardView(onOpen: {})
        IntelligenceUpgradeCardView()
    }
    .padding()
}
#endif
