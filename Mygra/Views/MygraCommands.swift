//
//  MygraCommands.swift
//  Mygra
//
//  Menu-bar commands, shown on iPadOS 26+ (menu bar) and when running on Mac.
//

import SwiftUI

struct MygraCommands: Commands {
    @Binding var pendingDeepLink: DeepLink?

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Migraine") {
                pendingDeepLink = .newMigraine
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("End Ongoing Migraine") {
                pendingDeepLink = .endOngoing
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        CommandMenu(Text("Go", comment: "Menu title for navigation commands")) {
            Button("Dashboard") {
                pendingDeepLink = .home
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Calendar") {
                pendingDeepLink = .calendar
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Migraines") {
                pendingDeepLink = .list
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("Settings") {
                pendingDeepLink = .settings
            }
            .keyboardShortcut("4", modifiers: [.command])

            Divider()

            Button("Migraine Assistant") {
                pendingDeepLink = .assistant
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
