//
//  MigraineFilter.swift
//  MygraCore
//
//  The list filter and its pure matching predicate.
//

import Foundation

nonisolated public struct MigraineFilter: Equatable, Sendable {
    public var pinnedOnly: Bool = false
    public var dateRange: ClosedRange<Date>? = nil
    public var minPainLevel: Int? = nil
    public var requiredTriggers: Set<MigraineTrigger> = []
    /// Searches note, insight, and custom triggers.
    public var searchText: String = ""

    public init(
        pinnedOnly: Bool = false,
        dateRange: ClosedRange<Date>? = nil,
        minPainLevel: Int? = nil,
        requiredTriggers: Set<MigraineTrigger> = [],
        searchText: String = ""
    ) {
        self.pinnedOnly = pinnedOnly
        self.dateRange = dateRange
        self.minPainLevel = minPainLevel
        self.requiredTriggers = requiredTriggers
        self.searchText = searchText
    }

    /// True when any criterion other than `pinnedOnly` is active.
    public var hasCriteria: Bool {
        dateRange != nil
            || minPainLevel != nil
            || !requiredTriggers.isEmpty
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when the filter differs from the default (everything shown).
    public var isActive: Bool {
        pinnedOnly || hasCriteria
    }

    /// Whether a migraine satisfies every active criterion of this filter.
    /// `pinnedOnly` is applied here too so callers can filter fully in memory.
    public func matches(_ migraine: Migraine) -> Bool {
        if pinnedOnly, !migraine.isPinned {
            return false
        }
        if let range = dateRange, !range.contains(migraine.startDate) {
            return false
        }
        if let minPain = minPainLevel, migraine.painLevel < minPain {
            return false
        }
        if !requiredTriggers.isEmpty {
            let present = Set(migraine.triggers)
            guard requiredTriggers.isSubset(of: present) else { return false }
        }
        if !searchText.isEmpty {
            let needle = searchText.lowercased()
            let noteHit = migraine.note?.lowercased().contains(needle) == true
            let insightHit = migraine.insight?.lowercased().contains(needle) == true
            let customHit = migraine.customTriggers.contains { $0.lowercased().contains(needle) }
            guard noteHit || insightHit || customHit else { return false }
        }
        return true
    }

    /// Short summary of the required triggers, e.g. "Triggers: Stress, Chocolate +2".
    public var requiredTriggerSummary: String {
        let names = requiredTriggers.map(\.displayName).sorted()
        let shown = names.prefix(3).joined(separator: ", ")
        if names.count <= 3 {
            return String(localized: "Triggers: \(shown)")
        }
        return String(localized: "Triggers: \(shown) +\(names.count - 3)")
    }
}
