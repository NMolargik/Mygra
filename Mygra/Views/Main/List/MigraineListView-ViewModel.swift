//
//  MigraineListView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import SwiftUI

extension MigraineListView {
    @Observable
    class ViewModel {
        var showingFilterSheet = false
        
        /// Returns a formatted date range string for the given migraine.
        /// Example: "Aug 28, 2025 at 3:41 PM – Aug 28, 2025 at 6:10 PM" or "… – ongoing"
        func dateRangeText(for migraine: Migraine) -> String {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            let start = df.string(from: migraine.startDate)
            if let end = migraine.endDate {
                return "\(start) – \(df.string(from: end))"
            } else {
                return "\(start) – ongoing"
            }
        }

        /// Returns a human-friendly summary of up to three trigger names for the given migraine.
        /// Appends "+N" if there are more than three triggers.
        func triggerSummary(for migraine: Migraine) -> String {
            let names = migraine.triggers.prefix(3).map { $0.displayName }
            var text = names.joined(separator: ", ")
            if migraine.triggers.count > 3 {
                text += " +\(migraine.triggers.count - 3)"
            }
            return text
        }
    }
}
