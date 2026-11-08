//
//  AttackModeStyle.swift
//  MygraDesignSystem
//
//  Turns the Core palette tokens into SwiftUI colors and gives Attack Mode its one button
//  look: a flat dim block with no highlight animation, no material, and no shadow.
//

import SwiftUI
import MygraCore

extension Color {
    /// A dim Attack Mode color from a Core token (sRGB, so it renders as specified).
    public init(_ token: AttackRGB) {
        self.init(.sRGB, red: token.red, green: token.green, blue: token.blue, opacity: 1)
    }
}

public enum AttackColors {
    public static let background = Color(AttackPalette.background)
    public static let primaryText = Color(AttackPalette.primaryText)
    public static let secondaryText = Color(AttackPalette.secondaryText)
    public static let buttonFill = Color(AttackPalette.buttonFill)
    public static let buttonFillSelected = Color(AttackPalette.buttonFillSelected)
    public static let border = Color(AttackPalette.border)
    public static let endText = Color(AttackPalette.endText)
    public static let endFill = Color(AttackPalette.endFill)
}

/// A large, flat, animation-free block button. Pressing swaps to the selected fill
/// instantly; nothing scales, fades, or glows.
public struct AttackBlockButtonStyle: ButtonStyle {
    private let isSelected: Bool
    private let isDestructive: Bool
    private let minHeight: CGFloat

    public init(isSelected: Bool = false, isDestructive: Bool = false, minHeight: CGFloat = 72) {
        self.isSelected = isSelected
        self.isDestructive = isDestructive
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        let highlighted = isSelected || configuration.isPressed
        configuration.label
            .foregroundStyle(isDestructive ? AttackColors.endText : AttackColors.primaryText)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                highlighted ? AttackColors.buttonFillSelected : (isDestructive ? AttackColors.endFill : AttackColors.buttonFill),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AttackColors.primaryText.opacity(0.6) : AttackColors.border, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .transaction { $0.animation = nil }
    }
}
