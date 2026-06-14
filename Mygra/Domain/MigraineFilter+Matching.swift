//
//  MigraineFilter+Matching.swift
//  Mygra
//
//  Pure filter-matching logic, extracted from MigraineManager for testability.
//

import Foundation

extension MigraineFilter {
    /// Whether a migraine satisfies every active criterion of this filter.
    /// `pinnedOnly` is intentionally not checked here — it is applied at the
    /// fetch level for performance.
    func matches(_ migraine: Migraine) -> Bool {
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
}
