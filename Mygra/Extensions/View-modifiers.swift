//
//  View-modifiers.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import SwiftUI

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }

    /// Applies a glass effect with the provided tint on iOS 26+,
    /// and falls back to a simple tinted background on earlier iOS versions.
    func adaptiveGlass(tint: Color) -> some View {
        self.modifier(AdaptiveGlassModifier(tint: tint))
    }

    /// The standard card surface — material fill, hairline border, soft shadow —
    /// without padding, for views that manage their own internal spacing.
    func cardSurface(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    /// Standard card styling used throughout the app: padded content on the
    /// shared card surface. Prefer `InsightCard` for titled cards.
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        self.padding(16).cardSurface(cornerRadius: cornerRadius)
    }

    /// Minimizes the toolbar on scroll where the OS supports it (iOS 27+).
    @ContentBuilder
    func minimizeToolbarOnScrollIfAvailable() -> some View {
        if #available(iOS 27.0, *) {
            self.toolbarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Conditionally applies a transform — keeps call sites declarative.
    @ContentBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension View {
    /// The app's standard action-button treatment. Uses the native Liquid
    /// Glass button styles on iOS 26+ (falling back to bordered styles), so
    /// call sites stop hand-rolling tinted glass pills. Reserve `prominent`
    /// for the single primary action in a given context.
    @ContentBuilder
    func glassActionButton(tint: Color = .mygraBlue, prominent: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent).tint(tint)
            } else {
                self.buttonStyle(.glass).tint(tint)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent).tint(tint)
            } else {
                self.buttonStyle(.bordered).tint(tint)
            }
        }
    }
}

/// Material pill background for compact stat chips.
struct StatPillBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous).fill(.ultraThinMaterial)
            )
            .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
    }
}

extension View {
    func statPillBackground() -> some View { modifier(StatPillBackground()) }
}

extension LinearGradient {
    /// The standard Mygra brand gradient (purple to blue, top-trailing to bottom-leading).
    @MainActor
    static var mygra: LinearGradient {
        LinearGradient(
            colors: [.mygraPurple, .mygraBlue],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
}



struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.35), Color.clear]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
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
 
struct DrawOnOffEffect: ViewModifier {
    let drawOn: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        content
            .symbolEffect(.pulse, options: .repeating, value: drawOn)
        #else
        content
            .symbolEffect(.pulse, options: .repeating, value: drawOn)
        #endif
    }
}
