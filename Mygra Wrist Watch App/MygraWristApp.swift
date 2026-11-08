//
//  MygraWristApp.swift
//  Mygra Wrist Watch App
//

import SwiftUI
import MygraCore

@main
struct MygraWristApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PhoneBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(PhoneBridge.shared)
                .onOpenURL { url in
                    // The Attack Mode complication / Smart Stack entry.
                    guard DeepLink(url: url) == .attackMode else { return }
                    Task { await PhoneBridge.shared.openAttackMode() }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        PhoneBridge.shared.refresh()
                    }
                }
        }
    }
}
