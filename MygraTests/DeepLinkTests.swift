//
//  DeepLinkTests.swift
//  MygraTests
//

import Foundation
import Testing
@testable import Mygra

@Suite("DeepLink URL parsing")
struct DeepLinkTests {
    @Test(arguments: [
        ("mygra://new-migraine", DeepLink.newMigraine),
        ("mygra://home", DeepLink.home),
        ("mygra://calendar", DeepLink.calendar),
        ("mygra://list", DeepLink.list),
        ("mygra://settings", DeepLink.settings),
        ("mygra://assistant", DeepLink.assistant),
        ("mygra://end-ongoing", DeepLink.endOngoing),
    ])
    func parsesKnownHosts(urlString: String, expected: DeepLink) throws {
        let url = try #require(URL(string: urlString))
        #expect(DeepLink(url: url) == expected)
    }

    @Test func parsesMigraineID() throws {
        let id = UUID()
        let url = try #require(URL(string: "mygra://migraine/\(id.uuidString)"))
        #expect(DeepLink(url: url) == .migraine(id))
    }

    @Test(arguments: [
        "mygra://migraine/not-a-uuid",
        "mygra://migraine",
        "mygra://unknown",
        "https://home",
        "otherapp://home",
    ])
    func rejectsInvalidURLs(urlString: String) throws {
        let url = try #require(URL(string: urlString))
        #expect(DeepLink(url: url) == nil)
    }

    @Test("every case round-trips through its URL")
    func roundTrip() throws {
        let id = UUID()
        let links: [DeepLink] = [.newMigraine, .home, .calendar, .list, .settings, .assistant, .endOngoing, .migraine(id)]
        for link in links {
            let url = try #require(link.url)
            #expect(DeepLink(url: url) == link)
        }
    }

    // MARK: - App Intent hand-off

    @Test("store then take returns the same deep link and clears it")
    func pendingHandoffRoundTrips() throws {
        let defaults = try #require(UserDefaults(suiteName: "DeepLinkTests.\(UUID().uuidString)"))
        DeepLink.calendar.storePending(in: defaults)
        #expect(DeepLink.takePending(from: defaults) == .calendar)
        // Second read is empty: the value is consumed.
        #expect(DeepLink.takePending(from: defaults) == nil)
    }

    @Test("taking from an empty store yields nil")
    func pendingHandoffEmpty() throws {
        let defaults = try #require(UserDefaults(suiteName: "DeepLinkTests.\(UUID().uuidString)"))
        #expect(DeepLink.takePending(from: defaults) == nil)
    }
}
