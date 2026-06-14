//
//  MigraineFilterTests.swift
//  MygraTests
//

import Foundation
import SwiftData
import Testing
@testable import Mygra

@Suite("MigraineFilter matching", .serialized)
@MainActor
struct MigraineFilterTests {
    @Test func emptyFilterMatchesEverything() throws {
        let container = try makeTestContainer()
        let m = makeMigraine(in: container.mainContext)
        #expect(MigraineFilter().matches(m))
    }

    @Test func dateRangeExcludesOutsideStarts() throws {
        let container = try makeTestContainer()
        let now = Date()
        let m = makeMigraine(in: container.mainContext, start: now.addingTimeInterval(-30 * 24 * 3600))

        var filter = MigraineFilter()
        filter.dateRange = now.addingTimeInterval(-14 * 24 * 3600)...now
        #expect(!filter.matches(m))

        filter.dateRange = now.addingTimeInterval(-60 * 24 * 3600)...now
        #expect(filter.matches(m))
    }

    @Test func minPainLevelIsInclusive() throws {
        let container = try makeTestContainer()
        let m = makeMigraine(in: container.mainContext, pain: 5)

        var filter = MigraineFilter()
        filter.minPainLevel = 5
        #expect(filter.matches(m))
        filter.minPainLevel = 6
        #expect(!filter.matches(m))
    }

    @Test func requiredTriggersDemandsAllPresent() throws {
        let container = try makeTestContainer()
        let m = makeMigraine(in: container.mainContext, triggers: [.stress, .dehydration])

        var filter = MigraineFilter()
        filter.requiredTriggers = [.stress]
        #expect(filter.matches(m))

        filter.requiredTriggers = [.stress, .dehydration]
        #expect(filter.matches(m))

        filter.requiredTriggers = [.stress, .brightLightGlare]
        #expect(!filter.matches(m))
    }

    @Test func searchTextScansNoteInsightAndCustomTriggers() throws {
        let container = try makeTestContainer()
        let m = makeMigraine(
            in: container.mainContext,
            note: "Long day at the OFFICE",
            customTriggers: ["red wine"]
        )

        var filter = MigraineFilter()
        filter.searchText = "office"
        #expect(filter.matches(m))

        filter.searchText = "wine"
        #expect(filter.matches(m))

        filter.searchText = "swimming"
        #expect(!filter.matches(m))
    }
}
