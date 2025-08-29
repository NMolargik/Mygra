//
//  MigraineFilter.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import Foundation

struct MigraineFilter: Equatable {
    var pinnedOnly: Bool = false
    var dateRange: ClosedRange<Date>? = nil
    var minPainLevel: Int? = nil
    var requiredTriggers: Set<MigraineTrigger> = []
    var searchText: String = "" // searches note/insight
}
