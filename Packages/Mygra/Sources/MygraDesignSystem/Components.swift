//
//  Components.swift
//  MygraDesignSystem
//
//  Reusable content components: titled cards, detail rows, metric rows, info pills,
//  stat tiles, and the Apple Intelligence badge.
//

import SwiftUI

// MARK: - InsightCard

/// The standard titled content card: a material surface with a restrained single-accent
/// gradient wash, a hairline border, and a soft shadow.
public struct InsightCard<Content: View>: View {
    let title: String?
    let systemImage: String?
    let accent: Color
    let content: Content

    public init(
        title: String? = nil,
        systemImage: String? = nil,
        accent: Color = .mygraBlue,
        @ContentBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            if let title {
                HStack {
                    if let systemImage {
                        Label(title, systemImage: systemImage)
                            .font(.headline.weight(.semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(accent, .primary)
                    } else {
                        Text(title)
                            .font(.headline.weight(.semibold))
                    }
                    Spacer(minLength: 0)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Brand.Space.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .fill(LinearGradient(colors: [accent.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous).strokeBorder(.quaternary))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - InfoDetailView

/// A titled detail section on the secondary system background.
public struct InfoDetailView<Content: View, Trailing: View>: View {
    let title: String
    let trailing: () -> Trailing
    let content: () -> Content

    public init(
        title: String,
        @ContentBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ContentBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                trailing()
            }
            content()
        }
        .padding(Brand.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.control + 2, style: .continuous)
                .fill(secondaryBackground)
        )
    }
}

/// The platform's secondary grouped background as a ShapeStyle.
public var secondaryBackground: Color {
    #if canImport(UIKit) && !os(watchOS)
    Color(uiColor: .secondarySystemBackground)
    #else
    Color.gray.opacity(0.15)
    #endif
}

/// The platform's tertiary background.
public var tertiaryBackground: Color {
    #if canImport(UIKit) && !os(watchOS)
    Color(uiColor: .tertiarySystemBackground)
    #else
    Color.gray.opacity(0.25)
    #endif
}

/// The platform's grouped background (onboarding pages, forms).
public var groupedBackground: Color {
    #if canImport(UIKit) && !os(watchOS)
    Color(uiColor: .systemGroupedBackground)
    #else
    Color.gray.opacity(0.1)
    #endif
}

/// The platform's secondary grouped background (cards inside grouped pages).
public var secondaryGroupedBackground: Color {
    #if canImport(UIKit) && !os(watchOS)
    Color(uiColor: .secondarySystemGroupedBackground)
    #else
    Color.gray.opacity(0.15)
    #endif
}

// MARK: - MetricRowView

/// A labeled row: title on the leading edge, value on the trailing edge.
public struct MetricRowView<Value: View>: View {
    let title: String
    let valueView: Value

    public init(_ title: String, @ContentBuilder value: () -> Value) {
        self.title = title
        self.valueView = value()
    }

    public init(_ title: String, value: String) where Value == Text {
        self.title = title
        self.valueView = Text(value)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            valueView
        }
    }
}

/// A tinted value chip plus icon, the trailing content of a detail metric row.
public struct MetricChip: View {
    let text: String
    let systemImage: String
    let tint: Color

    public init(_ text: String, systemImage: String, tint: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: Brand.Space.sm) {
            Text(text)
                .font(.callout).bold()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(tint.opacity(0.14)))
            Image(systemName: systemImage)
                .frame(width: 30)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - InfoPillView

public struct InfoPillView: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    public init(title: String, value: String, icon: String, tint: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: Brand.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, Brand.Space.md)
        .padding(.vertical, Brand.Space.sm)
        .background(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).fill(tint.opacity(0.12)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - StatTileView

/// A compact labeled statistic that bounces its icon when the value changes.
public struct StatTileView: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    @State private var bounceFlag = false

    public init(title: String, value: String, systemImage: String, color: Color) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color.gradient)
                    .symbolEffect(.bounce, options: .repeat(1), value: bounceFlag)
            }
            .font(.subheadline)

            Text(value)
                .font(.title3)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Brand.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        .onChange(of: value) { bounceFlag.toggle() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - DetailRowView

/// A leading icon in a tinted circle with a title (and optional subtitle/trailing).
public struct DetailRowView<Trailing: View>: View {
    public enum Style { case feature, insight }

    let style: Style
    let systemImage: String
    let title: String
    let subtitle: String?
    let tint: Color
    @ContentBuilder let trailing: () -> Trailing

    public init(
        style: Style,
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        tint: Color,
        @ContentBuilder trailing: @escaping () -> Trailing
    ) {
        self.style = style
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.trailing = trailing
    }

    public var body: some View {
        switch style {
        case .feature: featureBody
        case .insight: insightBody
        }
    }

    private var featureBody: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .frame(width: 40, height: 40)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Brand.Space.lg)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.control + 2, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.control + 2, style: .continuous))
        .shadow(radius: 6, y: 2)
    }

    private var insightBody: some View {
        HStack(alignment: .top, spacing: Brand.Space.md) {
            ZStack {
                Circle().fill(tint.opacity(0.12))
                Image(systemName: systemImage)
                    .symbolVariant(.fill)
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).bold()
                    .minimumScaleFactor(0.9)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                trailing()
                Spacer(minLength: 0)
            }
        }
        .padding(Brand.Space.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Brand.Radius.chip + 2, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension DetailRowView where Trailing == EmptyView {
    public init(style: Style, systemImage: String, title: String, subtitle: String? = nil, tint: Color) {
        self.init(style: style, systemImage: systemImage, title: title, subtitle: subtitle, tint: tint, trailing: { EmptyView() })
    }
}

// MARK: - Apple Intelligence

/// The rainbow "apple.intelligence" glyph.
public struct AppleIntelligenceSymbol: View {
    let isActive: Bool

    public init(isActive: Bool = false) {
        self.isActive = isActive
    }

    public var body: some View {
        Image(systemName: "apple.intelligence")
            .symbolEffect(.pulse, isActive: isActive)
            .foregroundStyle(AngularGradient.appleIntelligence)
    }
}

/// The "Powered by Apple Intelligence" capsule with a slow glow and an activity spinner.
public struct AppleIntelligenceBadge: View {
    let isGenerating: Bool

    @State private var animateGlow = false

    public init(isGenerating: Bool) {
        self.isGenerating = isGenerating
    }

    public var body: some View {
        HStack(spacing: 6) {
            AppleIntelligenceSymbol(isActive: isGenerating)
            Text("Powered by Apple Intelligence")
                .font(.caption)
                .foregroundStyle(.secondary)
                .overlay {
                    LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                        .mask(Text("Powered by Apple Intelligence").font(.caption))
                        .opacity(animateGlow ? 1 : 0.2)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateGlow)
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
        .onAppear { animateGlow = true }
    }
}

// MARK: - Weather attribution

/// The " Weather • Legal" attribution WeatherKit requires next to its data.
public struct WeatherAttributionView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            Text(" Weather")
            Text("•")
                .accessibilityHidden(true)
            Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                .foregroundStyle(.mygraPurple)
                .accessibilityLabel("Apple Weather legal attribution, opens in browser")
            Spacer()
        }
    }
}

// MARK: - Animated text

/// A subtle animated highlight sweeping across a headline.
public struct SparkleText: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let percent = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1))
            Text(text)
                .font(.title2)
                .bold()
                .foregroundStyle(.secondary)
                .overlay(
                    LinearGradient(colors: [Color.clear, Color.white.opacity(0.7), Color.clear], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 30)
                        .rotationEffect(.degrees(15))
                        .offset(x: percent * 350 - 200)
                        .blendMode(.plusLighter)
                        .mask(Text(text).font(.title2).bold())
                )
        }
        .padding()
    }
}

/// Three pulsing dots for "assistant is typing".
public struct TypingIndicator: View {
    public init() {}

    public var body: some View {
        TimelineView(.animation) { timeline in
            let duration: TimeInterval = 1.5
            let phase = CGFloat((timeline.date.timeIntervalSinceReferenceDate / duration).truncatingRemainder(dividingBy: 1))
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    let progress = wave(phase: phase, index: index)
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(0.95 + 0.20 * progress)
                        .opacity(0.6 + 0.4 * progress)
                }
            }
            .accessibilityLabel("Assistant is typing")
        }
    }

    private func wave(phase: CGFloat, index: Int) -> CGFloat {
        let offset = Double(index) * (2 * .pi / 3)
        let t = sin(Double(phase) * 2 * .pi - offset)
        return CGFloat((t + 1) / 2)
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 16) {
            InsightCard(title: "Today", systemImage: "sun.max", accent: .mygraBlue) {
                Text("No migraine today.").foregroundStyle(.secondary)
            }
            DetailRowView(style: .insight, systemImage: "drop.fill", title: "Low hydration on migraine days", subtitle: "Average water intake: 1.1 L on migraine days.", tint: .blue) {
                Text("High").font(.caption2)
            }
            StatTileView(title: "Water Intake", value: "32 oz", systemImage: "drop.fill", color: .blue)
            AppleIntelligenceBadge(isGenerating: true)
            TypingIndicator()
        }
        .padding()
    }
}
