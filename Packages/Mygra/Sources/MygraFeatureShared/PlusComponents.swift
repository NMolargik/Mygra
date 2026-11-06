//
//  PlusComponents.swift
//  MygraFeatureShared
//
//  Shared Plus chrome: the small "PLUS" badge on gated rows and the locked card a
//  gated dashboard section shows in place of its content.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

/// A compact capsule marking a Plus-only row or button.
public struct PlusBadge: View {
    public init() {}

    public var body: some View {
        Text("PLUS")
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(LinearGradient.mygraHorizontal, in: Capsule())
            .accessibilityLabel(Text("Mygra Plus"))
    }
}

/// What a gated dashboard section shows to free users: the feature, one line on why
/// it is worth it, and a single unlock action that opens the paywall for that feature.
public struct PlusLockedCard: View {
    let feature: PlusFeature
    let onUnlock: () -> Void

    public init(feature: PlusFeature, onUnlock: @escaping () -> Void) {
        self.feature = feature
        self.onUnlock = onUnlock
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Brand.Space.md) {
            Image(systemName: feature.systemImage)
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient.mygraHorizontal)
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Brand.Space.sm) {
                    Text(feature.title)
                        .font(.headline)
                    PlusBadge()
                }
                Text(feature.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onUnlock) {
                Label("Unlock", systemImage: "lock.open.fill")
            }
            .glassActionButton(tint: .mygraPurple)
            .hoverHighlight()
            .accessibilityLabel(Text("Unlock \(feature.title) with Mygra Plus"))
        }
        .padding(16)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}
#endif
