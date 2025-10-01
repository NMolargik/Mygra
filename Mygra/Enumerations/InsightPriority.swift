//
//  InsightPriority.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation

enum InsightPriority: Int, Comparable, Hashable {
    case low = 1
    case medium = 5
    case high = 9
    static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool { lhs.rawValue < rhs.rawValue }
}
