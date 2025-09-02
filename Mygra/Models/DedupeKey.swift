//
//  DedupeKey.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation

struct DedupeKey: Hashable {
    let category: InsightCategory
    let title: String
    let message: String
}
