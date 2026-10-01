//
//  Insight.swift
//  MygraCore
//
//  A generated insight card and its de-duplication key.
//

import Foundation

nonisolated public struct DedupeKey: Hashable, Sendable {
    public let category: InsightCategory
    public let title: String
    public let message: String

    public init(category: InsightCategory, title: String, message: String) {
        self.category = category
        self.title = title
        self.message = message
    }

    /// Stable string key combining fields; safe to use for lightweight caches.
    public var key: String { "\(category.rawValue)|\(title)|\(message)" }
}

public struct Insight: Identifiable, Hashable {
    public let id: UUID
    public let category: InsightCategory
    public let title: String
    public let message: String
    public let priority: InsightPriority
    public let generatedAt: Date
    public let tags: [String: AnyHashable]

    public init(
        id: UUID = UUID(),
        category: InsightCategory,
        title: String,
        message: String,
        priority: InsightPriority,
        generatedAt: Date = Date(),
        tags: [String: AnyHashable] = [:]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.priority = priority
        self.generatedAt = generatedAt
        self.tags = tags
    }

    /// Priority (high first), then category, then newest.
    public static func sorter(lhs: Insight, rhs: Insight) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
        return lhs.generatedAt > rhs.generatedAt
    }

    public var dedupeKey: DedupeKey { DedupeKey(category: category, title: title, message: message) }

    /// Convenience typed accessor for a numeric tag.
    public func doubleTag(_ key: String) -> Double? {
        switch tags[key] {
        case let value as Double: return value
        case let value as Int: return Double(value)
        default: return nil
        }
    }
}

/// The two-part explanation the assistant produces for a Quick Bit.
nonisolated public struct QuickBitExplanation: Codable, Equatable, Sendable {
    public let description: String
    public let recommendation: String

    public init(description: String, recommendation: String) {
        self.description = description
        self.recommendation = recommendation
    }
}

/// One turn of the assistant conversation.
nonisolated public struct ChatMessage: Hashable, Sendable {
    public let role: ChatRole
    public let content: String

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }

    public static func system(_ text: String) -> ChatMessage { .init(role: .system, content: text) }
    public static func user(_ text: String) -> ChatMessage { .init(role: .user, content: text) }
    public static func assistant(_ text: String) -> ChatMessage { .init(role: .assistant, content: text) }
}
