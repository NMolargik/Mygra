//
//  MygraApp.swift
//  Mygra
//
//  Created by Nick Molargik on 7/13/25.
//

import SwiftUI
import SwiftData

/// The main app declaration
@main
struct MygraApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Migraine.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.molargiksoftware.Mygra")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MygraRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
