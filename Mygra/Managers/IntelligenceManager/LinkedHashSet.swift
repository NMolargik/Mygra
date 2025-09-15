//
//  LinkedHashSet.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import Foundation

struct LinkedHashSet<Element, Key: Hashable> {
    private var orderedStorage: [Element] = []
    private var seenKeys: Set<Key> = []

    init<S: Sequence>(elements: S, key: (Element) -> Key) where S.Element == Element {
        for e in elements {
            let k = key(e)
            if seenKeys.insert(k).inserted {
                orderedStorage.append(e)
            }
        }
    }

    var ordered: [Element] { orderedStorage }
}
