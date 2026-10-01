//
//  LevelSlider.swift
//  MygraFeatureShared
//
//  A labeled 0–10 slider for pain and stress, shared by entry, modify, and intensity
//  update forms.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct LevelSlider: View {
    let title: LocalizedStringKey
    @Binding var level: Int
    let tint: Color

    public init(_ title: LocalizedStringKey, level: Binding<Int>, tint: Color) {
        self.title = title
        _level = level
        self.tint = tint
    }

    /// Pain slider tinted by severity.
    public static func pain(level: Binding<Int>) -> LevelSlider {
        LevelSlider("Pain Level", level: level, tint: Severity.from(painLevel: level.wrappedValue).color)
    }

    /// Stress slider in indigo.
    public static func stress(level: Binding<Int>) -> LevelSlider {
        LevelSlider("Stress Level", level: level, tint: .indigo)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(level)")
                    .bold()
                    .foregroundStyle(tint)
            }
            Slider(
                value: Binding(get: { Double(level) }, set: { level = Int($0.rounded()) }),
                in: 0...10,
                step: 1
            )
            .tint(tint)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text("\(level) out of 10"))
        }
    }
}
#endif
