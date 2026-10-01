//
//  BrandColors.swift
//  MygraDesignSystem
//
//  The brand palette, defined in code (the app's asset catalog isn't visible to package
//  modules). Values match the original Assets.xcassets colorsets (Display P3). Available
//  both as `Color.mygraBlue` members and in `.foregroundStyle(.mygraBlue)` positions.
//

import SwiftUI

extension Color {
    public static let mygraBlue = Color(.displayP3, red: 0x6C / 255, green: 0xB8 / 255, blue: 0xF4 / 255)
    public static let mygraPurple = Color(.displayP3, red: 0x6E / 255, green: 0x60 / 255, blue: 0xFF / 255)
}

extension ShapeStyle where Self == Color {
    public static var mygraBlue: Color { Color.mygraBlue }
    public static var mygraPurple: Color { Color.mygraPurple }
}

@MainActor extension LinearGradient {
    /// The standard Mygra brand gradient (purple to blue, top-trailing to bottom-leading).
    public static var mygra: LinearGradient {
        LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    /// The brand gradient as a soft page wash.
    public static var mygraWash: LinearGradient {
        LinearGradient(
            colors: [Color.mygraPurple.opacity(0.25), Color.mygraBlue.opacity(0.25)],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    /// Horizontal purple → blue, for inline text and icons.
    public static var mygraHorizontal: LinearGradient {
        LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .leading, endPoint: .trailing)
    }
}

@MainActor extension AngularGradient {
    /// The Apple Intelligence rainbow ring.
    public static var appleIntelligence: AngularGradient {
        AngularGradient(
            colors: [.orange, .red, .purple, .blue, .purple, .red, .orange, .orange],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}
