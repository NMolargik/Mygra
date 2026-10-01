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
        #expect(MygraScreen.assistant.deepLink == .assistant)
    }

    @Test("Every background intent is surfaced as an App Shortcut")
    func shortcutsCoverIntents() {
        #expect(MygraShortcuts.appShortcuts.count == 4)
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
