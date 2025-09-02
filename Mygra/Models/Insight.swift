//
//  Insight.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation

struct Insight: Identifiable, Hashable {
    let id: UUID
    let category: InsightCategory
    let title: String
    let message: String
    let priority: InsightPriority
    let generatedAt: Date
    let tags: [String: AnyHashable]

    init(
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

    static func sorter(lhs: Insight, rhs: Insight) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
        return lhs.generatedAt > rhs.generatedAt
    }
    
    var dedupeKey: DedupeKey { DedupeKey(category: category, title: title, message: message) }
}
