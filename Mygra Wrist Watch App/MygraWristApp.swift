//
//  MygraWristApp.swift
//  Mygra Wrist Watch App
//

import SwiftUI

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
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        PhoneBridge.shared.refresh()
                    }
                }
        }
    }
}
