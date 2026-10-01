//
//  AppRouterTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("AppRouter")
@MainActor
struct AppRouterTests {
    @Test("opening a link jumps to its tab and stages the link")
    func openSelectsTabAndStages() {
        let router = AppRouter()
        router.open(.calendar)
        #expect(router.selectedTab == .calendar)
        #expect(router.pendingDeepLink == .calendar)

        let id = UUID()
        router.open(.migraine(id))
        #expect(router.selectedTab == .list)
        #expect(router.pendingDeepLink == .migraine(id))

        router.open(.tags)
        #expect(router.selectedTab == .settings)
    }

    @Test("links without a destination keep the current tab")
    func tablessLinksKeepTab() {
        let router = AppRouter()
        router.select(.settings)
        router.open(.assistant)
        #expect(router.selectedTab == .settings)
        #expect(router.pendingDeepLink == .assistant)
        router.open(.endOngoing)
        #expect(router.selectedTab == .settings)
    }

    @Test("URLs route when valid and are ignored otherwise")
    func urlRouting() throws {
        let router = AppRouter()
        #expect(router.open(url: try #require(URL(string: "mygra://new-migraine"))))
        #expect(router.selectedTab == .dashboard)
        #expect(router.pendingDeepLink == .newMigraine)

        router.select(.list)
        #expect(!router.open(url: try #require(URL(string: "https://example.com"))))
        #expect(router.selectedTab == .list)
        #expect(router.pendingDeepLink == .newMigraine)
    }

    @Test("taking the pending link clears it")
    func takeClears() {
        let router = AppRouter()
        router.open(.settings)
        #expect(router.takePendingDeepLink() == .settings)
        #expect(router.pendingDeepLink == nil)
        #expect(router.takePendingDeepLink() == nil)
    }
}
