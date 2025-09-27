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
    
    static var previewValue: MigraineFilter {
        var f = MigraineFilter()
        // Example defaults for preview
        f.minPainLevel = 3
        f.searchText = ""
        // Leave dateRange and requiredTriggers empty by default
        return f
    }

    static var previewWithRange: MigraineFilter {
        var f = MigraineFilter.previewValue
        let now = Date()
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        f.dateRange = twoWeeksAgo...now
        return f
    }
}
