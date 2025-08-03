//
//  MigrainesViewModel.swift
//  Mygra
//
//  Created by [Your Name] on 8/3/25.
//

import SwiftUI
import SwiftData

@Observable
class MigrainesViewModel {
    var modelContext: ModelContext?
    var filterSeverity: Migraine.Severity? = nil
    var filterDateRange: ClosedRange<Date>? = nil
    
    var isFiltered: Bool {
        filterSeverity != nil || filterDateRange != nil
    }
    
    func filteredMigraines(_ migraines: [Migraine], showPinnedOnly: Bool) -> [Migraine] {
        migraines.filter { migraine in
            var matches = true
            if let severity = filterSeverity {
                matches = matches && (migraine.severity == severity)
            }
            if let dateRange = filterDateRange {
                matches = matches && dateRange.contains(migraine.timestamp)
            }
            if showPinnedOnly {
                matches = matches && migraine.isPinned
            }
            return matches
        }
    }
    
    func deleteMigraines(at offsets: IndexSet, filtered: [Migraine]) {
        guard let context = modelContext else { return }
        for index in offsets {
            context.delete(filtered[index])
        }
    }
}
