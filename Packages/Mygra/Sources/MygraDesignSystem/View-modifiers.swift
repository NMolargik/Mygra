//
//  View-modifiers.swift
//  MygraDesignSystem
//
//  The shared building blocks of the HIG / Liquid Glass surface language: card
//  surfaces, the standard action buttons, OS-gated tab/toolbar accessories, stat pills,
//  shimmer, hover affordances, and small conditionals. Everything that needs an iOS 26+
//  or 27+ API is gated here once so feature code stays free of `#available` noise.
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
    @ContentBuilder
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

    /// Pointer/hover highlight for iPad trackpads and Mac — a no-op elsewhere.
    @ContentBuilder
    public func hoverHighlight() -> some View {
        #if os(iOS)
        hoverEffect(.highlight)
        #else
        self
        #endif
    }

    /// Pointer lift for card-like tappable surfaces.
    @ContentBuilder
    public func hoverLift() -> some View {
        #if os(iOS)
        hoverEffect(.lift)
        #else
        self
        #endif
    }
}

// MARK: - Buttons

#if os(iOS)
extension View {
    /// The app's standard action-button treatment: native Liquid Glass button styles on
    /// iOS 26+ (bordered fallback), so call sites never hand-roll tinted glass pills.
    /// Reserve `prominent` for the single primary action in a given context.
    @ContentBuilder
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
    @ContentBuilder
    public func glassActionButton(tint: Color = .mygraBlue, prominent: Bool = true) -> some View {
        if prominent {
            buttonStyle(.borderedProminent).tint(tint)
        } else {
            buttonStyle(.bordered).tint(tint)
        }
    }
}
#endif

extension View {
    /// The full-width primary call to action (onboarding, splash, end-migraine): large
    /// prominent glass in the brand purple, readable-width capped.
    public func primaryActionButton(tint: Color = .mygraPurple) -> some View {
        glassActionButton(tint: tint, prominent: true)
            .controlSize(.large)
            .frame(maxWidth: Brand.readableWidth)
            .hoverHighlight()
    }

    /// The full-width secondary call to action next to a primary one.
    public func secondaryActionButton(tint: Color = .mygraBlue) -> some View {
        glassActionButton(tint: tint, prominent: false)
            .controlSize(.large)
            .frame(maxWidth: Brand.readableWidth)
            .hoverHighlight()
    }
}

// MARK: - OS-gated navigation chrome

extension View {
    /// Attaches a tab-bar bottom accessory where it belongs — an iPhone/iPad idiom on
    /// iOS 26+. The accessory is always present, so give it content worth the space
    /// (a status strip, a persistent action); an empty accessory still renders as a
    /// blank glass bar. No-op on earlier releases and on Mac ("Designed for iPad"),
    /// where a floating bottom accessory reads as out of place under the Mac chrome.
    @ContentBuilder
    public func tabViewBottomAccessoryIfAvailable<Accessory: View>(@ContentBuilder _ accessory: () -> Accessory) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac {
            tabViewBottomAccessory(content: accessory)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Lets the tab bar collapse while scrolling down (iOS 26+), giving content room.
    @ContentBuilder
    public func minimizeTabBarOnScrollIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Lets the search field minimize into the toolbar (iOS 26+).
    @ContentBuilder
    public func minimizingSearchIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            searchToolbarBehavior(.minimize)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Soft scroll-edge effect under glass bars (iOS 26+), hard edge otherwise.
    @ContentBuilder
    public func softScrollEdgesIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Lets a hero image extend under the glass navigation bar (iOS 26+).
    @ContentBuilder
    public func backgroundExtensionIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// A navigation subtitle under the large title (iOS 26+), ignored elsewhere.
    @ContentBuilder
    public func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            navigationSubtitle(subtitle)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

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

// MARK: - Label styles

/// A label whose icon sits in a fixed-width column so stacked rows align (Settings,
/// feature lists). Mirrors the suite-wide `AlignedIconLabelStyle`.
public struct AlignedIconLabelStyle: LabelStyle {
    let width: CGFloat

    public init(width: CGFloat = 28) {
        self.width = width
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Brand.Space.md) {
            configuration.icon
                .frame(width: width, alignment: .center)
            configuration.title
        }
    }
}

extension LabelStyle where Self == AlignedIconLabelStyle {
    public static var alignedIcon: AlignedIconLabelStyle { AlignedIconLabelStyle() }
}

/// The iOS-Settings idiom: a white glyph on a tinted rounded square, then the title.
public struct SettingsIconLabelStyle: LabelStyle {
    let tint: Color

    public init(tint: Color) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Brand.Space.md) {
            configuration.icon
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.gradient))
                .accessibilityHidden(true)
            configuration.title
                .foregroundStyle(.primary)
        }
    }
}

extension LabelStyle where Self == SettingsIconLabelStyle {
    /// `Label("Units", systemImage: "ruler").labelStyle(.settingsIcon(.green))`
    public static func settingsIcon(_ tint: Color) -> SettingsIconLabelStyle { SettingsIconLabelStyle(tint: tint) }
}
