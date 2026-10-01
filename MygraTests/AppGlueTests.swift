//
//  AppGlueTests.swift
//  MygraTests
//
//  App-target glue only: the real suite lives in Packages/Mygra/Tests (host-run via
//  `swift test`). Here we cover what only exists in the app target — the Siri screen
//  enum and the App Shortcuts surface.
//
//  Deliberately no SwiftData here: the hosted app already owns a container for the
//  models, and opening a second one for the same classes in-process crashes SwiftData.
//

import AppIntents
import Foundation
import Testing
import MygraCore
@testable import Mygra

@Suite("App glue")
@MainActor
struct AppGlueTests {

    @Test("Every screen maps to its deep link")
    func screenDeepLinks() {
        #expect(MygraScreen.dashboard.deepLink == .home)
        #expect(MygraScreen.calendar.deepLink == .calendar)
        #expect(MygraScreen.migraines.deepLink == .list)
        #expect(MygraScreen.settings.deepLink == .settings)
        #expect(MygraScreen.tags.deepLink == .tags)
        #expect(MygraScreen.assistant.deepLink == .assistant)
    }

    @Test("Every background intent is surfaced as an App Shortcut")
    func shortcutsCoverIntents() {
        #expect(MygraShortcuts.appShortcuts.count == 6)
    }

    @Test("Quick actions declared in Info.plist are valid deep links")
    func quickActionsRoute() throws {
        let items = try #require(Bundle.main.object(forInfoDictionaryKey: "UIApplicationShortcutItems") as? [[String: Any]])
        #expect(items.count == 4)
        for item in items {
            let type = try #require(item["UIApplicationShortcutItemType"] as? String)
            let url = try #require(URL(string: type))
            #expect(DeepLink(url: url) != nil, "\(type) must parse as a deep link")
        }
    }

    @Test("The quick-action relay hands its URL to the session's router once")
    func quickActionRelay() throws {
        let relay = QuickActionRelay()
        #expect(relay.url == nil)
        relay.url = DeepLink.calendar.url
        let router = AppRouter()
        #expect(router.open(url: try #require(relay.url)))
        relay.url = nil
        #expect(router.selectedTab == .calendar)
        #expect(router.pendingDeepLink == .calendar)
    }

    @Test("The activity annotator tags the detail activity with the entity identifier")
    func activityAnnotation() {
        let activity = NSUserActivity(activityType: UserActivityType.viewingMigraine)
        let id = UUID()
        MigraineActivityAnnotator().annotate(activity, migraineID: id)
        if #available(iOS 18.2, *) {
            #expect(activity.appEntityIdentifier != nil)
        }
    }

    @Test("The entity mirrors the migraine it indexes")
    func entityMirrorsMigraine() {
        let migraine = Migraine(startDate: Date(), painLevel: 7, stressLevel: 3, note: "Bright lights", triggers: [.stress], customTriggers: ["Deadline"])
        let entity = MigraineEntity(migraine)
        #expect(entity.id == migraine.id)
        #expect(entity.painLevel == 7)
        #expect(entity.triggerNames == ["Stress", "Deadline"])
        #expect(entity.attributeSet.keywords?.contains("Deadline") == true)
    }
}
