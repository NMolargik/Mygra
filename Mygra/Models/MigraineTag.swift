//
//  MigraineTag.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import Foundation
import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// A user-defined tag for categorizing migraines.
/// Supports CloudKit sync via SwiftData.
@Model
final class MigraineTag {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()

    // MARK: - Properties
    /// The display name of the tag.
    var name: String = ""

    /// The color stored as a hex string for CloudKit compatibility.
    /// CloudKit doesn't support Color directly.
    var colorHex: String = "#8B5CF6"  // Default purple

    // MARK: - Relationships
    /// The migraines associated with this tag.
    /// Many-to-many relationship with Migraine.
    var migraines: [Migraine]?

    // MARK: - Init
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String = "",
        colorHex: String = "#8B5CF6"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.colorHex = colorHex
    }

    // MARK: - Computed Properties

    /// Returns the SwiftUI Color from the hex string.
    var color: Color {
        Color(hex: colorHex) ?? .purple
    }

    /// Sets the color by converting it to a hex string.
    func setColor(_ color: Color) {
        self.colorHex = color.toHex() ?? "#8B5CF6"
    }
}

// MARK: - Color Extensions for Hex Conversion

extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF5733" or "FF5733").
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Convert this Color to a hex string.
    func toHex() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return nil
        #endif
    }
}
