//
//  View-modifiers.swift
//  MygraDesignSystem
//
//  The shared building blocks of the HIG / Liquid Glass surface language: card
//  surfaces, the standard action button, stat pills, shimmer, and small conditionals.
//

import SwiftUI

// MARK: - Glass

public struct AdaptiveGlassModifier: ViewModifier {
    let tint: Color

    public init(tint: Color) {
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive().tint(tint))
        } else {
            content.background(tint).cornerRadius(20)
        }
        #else
        content.background(tint).cornerRadius(20)
        #endif
    }
}

extension View {
    /// Applies a glass effect with the provided tint on iOS 26+, falling back to a
    /// simple tinted background on earlier releases.
    public func adaptiveGlass(tint: Color) -> some View {
        modifier(AdaptiveGlassModifier(tint: tint))
    }

    /// The standard card surface — material fill, hairline border, soft shadow — without
    /// padding, for views that manage their own internal spacing.
    public func cardSurface(cornerRadius: CGFloat = Brand.Radius.card) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    /// Standard card styling: padded content on the shared card surface. Prefer
    /// `InsightCard` for titled cards.
    public func cardStyle(cornerRadius: CGFloat = Brand.Radius.card) -> some View {
        padding(Brand.Space.lg).cardSurface(cornerRadius: cornerRadius)
    }

    /// Conditionally applies a transform — keeps call sites declarative.
    @ViewBuilder
    public func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition { transform(self) } else { self }
    }

    public func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// Material pill background for compact stat chips.
    public func statPillBackground() -> some View {
        modifier(StatPillBackground())
    }
}

#if os(iOS)
extension View {
    /// The app's standard action-button treatment: native Liquid Glass button styles on
    /// iOS 26+ (bordered fallback), so call sites never hand-roll tinted glass pills.
    /// Reserve `prominent` for the single primary action in a given context.
    @ViewBuilder
    public func glassActionButton(tint: Color = .mygraBlue, prominent: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent).tint(tint)
            } else {
                buttonStyle(.glass).tint(tint)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent).tint(tint)
            } else {
                buttonStyle(.bordered).tint(tint)
            }
        }
    }
}
#else
extension View {
    @ViewBuilder
    public func glassActionButton(tint: Color = .mygraBlue, prominent: Bool = true) -> some View {
        if prominent {
            buttonStyle(.borderedProminent).tint(tint)
        } else {
            buttonStyle(.bordered).tint(tint)
        }
    }
}
#endif

// MARK: - Pills & shimmer

public struct StatPillBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
            .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.35), Color.clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                .mask(content)
                .offset(x: phase * 180)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
