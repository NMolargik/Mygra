//
//  Sequence-uniqued.swift
//  MygraCore
//
//  Order-preserving de-duplication (successor to the old LinkedHashSet type).
//

import Foundation

nonisolated extension Sequence {
    /// The elements of the sequence with duplicates (by `key`) removed, keeping the
    /// first occurrence and the original order.
    public func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}

nonisolated extension Sequence where Element: Hashable {
    /// The elements of the sequence with duplicates removed, keeping the first
    /// occurrence and the original order.
    public func uniqued() -> [Element] {
        uniqued(by: { $0 })
    }
}
