//
//  MygraCommands.swift
//  Mygra
//
//  Menu-bar / hardware-keyboard commands (iPadOS 26+ menu bar and Mac). Navigation is
//  driven through the same deep-link staging the app uses for widgets and App Intents.
//

import SwiftUI
import MygraComposition
import MygraCore

struct MygraCommands: Commands {
    let session: SessionController

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Migraine") { session.pendingDeepLink = .newMigraine }
                .keyboardShortcut("n", modifiers: [.command])
            Button("End Ongoing Migraine") { session.pendingDeepLink = .endOngoing }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        CommandMenu(Text("Go", comment: "Menu title for navigation commands")) {
            Button("Dashboard") { session.pendingDeepLink = .home }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Calendar") { session.pendingDeepLink = .calendar }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Migraines") { session.pendingDeepLink = .list }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Settings") { session.pendingDeepLink = .settings }
                .keyboardShortcut("4", modifiers: [.command])

            Divider()

            Button("Migraine Assistant") { session.pendingDeepLink = .assistant }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
