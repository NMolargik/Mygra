//
//  Mygra_WristApp.swift
//  Mygra Wrist Watch App
//
//  Created by Nick Molargik on 10/1/25.
//

import SwiftUI

@main
struct Mygra_Wrist_Watch_AppApp: App {
    init() {
        PhoneBridge.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
