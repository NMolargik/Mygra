//
//  MigraineTag.swift
//  MygraCore
//
//  A user-defined tag for categorizing migraines. The color is a hex string (CloudKit
//  can't store Color); the SwiftUI conversion lives in MygraDesignSystem.
//

import Foundation
import SwiftData

@Model
public final class MigraineTag {
    /// The default tag color (purple), as a hex string.
    public static let defaultColorHex = "#8B5CF6"

    // MARK: - Identity
    public var id: UUID = UUID()
    public var createdAt: Date = Date()

    // MARK: - Properties
    /// The display name of the tag.
    public var name: String = ""
    /// The color stored as a hex string for CloudKit compatibility.
    public var colorHex: String = MigraineTag.defaultColorHex
    /// User-defined ordering for the tag list. Lower comes first.
    public var sortIndex: Int = 0

    // MARK: - Relationships
    /// The migraines associated with this tag (many-to-many).
    public var migraines: [Migraine]?

    // MARK: - Init
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String = "",
        colorHex: String = MigraineTag.defaultColorHex,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }

    /// Number of migraines carrying this tag.
    public var migraineCount: Int { migraines?.count ?? 0 }
}
