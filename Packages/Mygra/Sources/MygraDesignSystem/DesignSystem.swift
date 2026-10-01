//
//  DesignSystem.swift
//  MygraDesignSystem
//
//  Shared visual language: spacing/radius tokens and the hex ↔ Color bridge that
//  MigraineTag's persisted color uses.
//

import SwiftUI

// MARK: - Brand

nonisolated public enum Brand {
    /// Spacing scale (4-pt grid).
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    /// Continuous corner radii.
    public enum Radius {
        public static let chip: CGFloat = 10
        public static let control: CGFloat = 14
        public static let card: CGFloat = 18
        public static let sheet: CGFloat = 24
    }

    /// The readable width for centered forms and onboarding content.
    public static let readableWidth: CGFloat = 500
}

// MARK: - Hex colors

nonisolated extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF5733" or "FF5733").
    public init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// This color as a "#RRGGBB" string (sRGB), or nil when it can't be resolved.
    public func toHex() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        return String(format: "#%02X%02X%02X", Int(components[0] * 255), Int(components[1] * 255), Int(components[2] * 255))
        #elseif canImport(AppKit)
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
        #else
        return nil
        #endif
    }
}
