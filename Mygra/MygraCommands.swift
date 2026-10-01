//
//  MygraCommands.swift
//  Mygra
//
//  Menu-bar / hardware-keyboard commands (iPadOS 26+ menu bar and Mac). Navigation is
//  driven through the same `AppRouter` the app uses for widgets, quick actions, and
//  App Intents, so every entry point behaves identically.
//

import SwiftUI
import MygraComposition
import MygraCore

struct MygraCommands: Commands {
    let session: SessionController

    private var router: AppRouter { session.router }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Migraine") { router.open(.newMigraine) }
                .keyboardShortcut("n", modifiers: [.command])
            Button("End Ongoing Migraine") { router.open(.endOngoing) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!session.hasOngoingMigraine)
        }

        CommandMenu(Text("Go", comment: "Menu title for navigation commands")) {
            ForEach(AppTab.allCases) { tab in
                Button(tab.title) { router.select(tab) }
                    .keyboardShortcut(KeyEquivalent(Character(String(tab.keyboardNumber))), modifiers: [.command])
            }

            Divider()

            Button("Manage Tags") { router.open(.tags) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Migraine Assistant") { router.open(.assistant) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Link("Mygra Website", destination: URL(string: "https://www.molargiksoftware.com")!)
        }
    }
}
