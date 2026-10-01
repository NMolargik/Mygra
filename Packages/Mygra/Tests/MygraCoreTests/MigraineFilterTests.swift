//
//  MigraineFilterTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("MigraineFilter matching")
@MainActor
struct MigraineFilterTests {
    @Test func emptyFilterMatchesEverything() {
        #expect(MigraineFilter().matches(makeMigraine()))
        #expect(!MigraineFilter().isActive)
    }

    @Test func pinnedOnlyExcludesUnpinned() {
        let filter = MigraineFilter(pinnedOnly: true)
        let unpinned = makeMigraine()
        let pinned = makeMigraine()
        pinned.isPinned = true
        #expect(!filter.matches(unpinned))
        #expect(filter.matches(pinned))
        #expect(filter.isActive)
        #expect(!filter.hasCriteria)
    }

    @Test func dateRangeExcludesOutsideStarts() {
        let now = Date()
        let migraine = makeMigraine(start: now.addingTimeInterval(-30 * 86_400))
        var filter = MigraineFilter()
        filter.dateRange = now.addingTimeInterval(-14 * 86_400)...now
        #expect(!filter.matches(migraine))
        filter.dateRange = now.addingTimeInterval(-60 * 86_400)...now
        #expect(filter.matches(migraine))
    }

    @Test func minPainLevelIsInclusive() {
        let migraine = makeMigraine(pain: 5)
        var filter = MigraineFilter()
        filter.minPainLevel = 5
        #expect(filter.matches(migraine))
        filter.minPainLevel = 6
        #expect(!filter.matches(migraine))
    }

    @Test func requiredTriggersDemandsAllPresent() {
        let migraine = makeMigraine(triggers: [.stress, .dehydration])
        var filter = MigraineFilter()
        filter.requiredTriggers = [.stress]
        #expect(filter.matches(migraine))
        filter.requiredTriggers = [.stress, .dehydration]
        #expect(filter.matches(migraine))
        filter.requiredTriggers = [.stress, .brightLightGlare]
        #expect(!filter.matches(migraine))
    }

    @Test func searchTextScansNoteInsightAndCustomTriggers() {
        let migraine = makeMigraine(note: "Long day at the OFFICE", customTriggers: ["red wine"])
        var filter = MigraineFilter()
        filter.searchText = "office"
        #expect(filter.matches(migraine))
        filter.searchText = "wine"
        #expect(filter.matches(migraine))
        filter.searchText = "swimming"
        #expect(!filter.matches(migraine))
    }

    @Test func requiredTriggerSummaryTruncatesAfterThree() {
        var filter = MigraineFilter()
        filter.requiredTriggers = [.stress, .chocolate, .dehydration, .jetLag]
        #expect(filter.requiredTriggerSummary.hasSuffix("+1"))
        filter.requiredTriggers = [.stress]
        #expect(filter.requiredTriggerSummary == "Triggers: Stress")
    }
}
