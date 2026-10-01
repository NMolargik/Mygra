//
//  DeepLinkTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("DeepLink URL parsing")
struct DeepLinkTests {
    @Test(arguments: [
        ("mygra://new-migraine", DeepLink.newMigraine),
        ("mygra://home", DeepLink.home),
        ("mygra://calendar", DeepLink.calendar),
        ("mygra://list", DeepLink.list),
        ("mygra://settings", DeepLink.settings),
        ("mygra://tags", DeepLink.tags),
        ("mygra://assistant", DeepLink.assistant),
        ("mygra://end-ongoing", DeepLink.endOngoing),
    ])
    func parsesKnownHosts(urlString: String, expected: DeepLink) throws {
        let url = try #require(URL(string: urlString))
        #expect(DeepLink(url: url) == expected)
    }

    @Test func parsesMigraineIDIgnoringQuery() throws {
        let id = UUID()
        #expect(DeepLink(url: try #require(URL(string: "mygra://migraine/\(id.uuidString)"))) == .migraine(id))
        #expect(DeepLink(url: try #require(URL(string: "mygra://migraine/\(id.uuidString)?action=end"))) == .migraine(id))
    }

    @Test(arguments: ["mygra://migraine/not-a-uuid", "mygra://migraine", "mygra://unknown", "https://home", "otherapp://home"])
    func rejectsInvalidURLs(urlString: String) throws {
        let url = try #require(URL(string: urlString))
        #expect(DeepLink(url: url) == nil)
    }

    @Test("every case round-trips through its URL")
    func roundTrip() {
        let links: [DeepLink] = [.newMigraine, .home, .calendar, .list, .settings, .tags, .assistant, .endOngoing, .migraine(UUID())]
        for link in links {
            #expect(DeepLink(url: link.url) == link)
        }
    }

    @Test("every link lands on the right tab")
    func destinationTabs() {
        #expect(DeepLink.home.destinationTab == .dashboard)
        #expect(DeepLink.newMigraine.destinationTab == .dashboard)
        #expect(DeepLink.calendar.destinationTab == .calendar)
        #expect(DeepLink.list.destinationTab == .list)
        #expect(DeepLink.migraine(UUID()).destinationTab == .list)
        #expect(DeepLink.settings.destinationTab == .settings)
        #expect(DeepLink.tags.destinationTab == .settings)
        #expect(DeepLink.assistant.destinationTab == nil)
        #expect(DeepLink.endOngoing.destinationTab == nil)
    }

    @Test("store then take returns the same deep link and clears it")
    func pendingHandoffRoundTrips() {
        let defaults = FakeKeyValueStore()
        DeepLink.calendar.storePending(in: defaults)
        #expect(DeepLink.takePending(from: defaults) == .calendar)
        #expect(DeepLink.takePending(from: defaults) == nil)
    }

    @Test("taking from an empty store yields nil")
    func pendingHandoffEmpty() {
        #expect(DeepLink.takePending(from: FakeKeyValueStore()) == nil)
    }
}
