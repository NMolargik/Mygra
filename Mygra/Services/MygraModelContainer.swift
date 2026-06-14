//
//  MygraModelContainer.swift
//  Mygra
//
//  The single production ModelContainer definition, shared by the app's
//  composition root and by App Intents (which run in-process and need their
//  own access to the SwiftData store).
//

import Foundation
import SwiftData
import os

enum MygraModelContainer {
    static let cloudKitContainerID = "iCloud.com.molargiksoftware.Mygra"

    /// The model types persisted by the app.
    static let schema: [any PersistentModel.Type] = [
        User.self, Migraine.self, WeatherData.self, HealthData.self, MigraineTag.self, IntensitySample.self
    ]

    /// Builds the production container. Uses CloudKit mirroring normally and an
    /// in-memory store under the unit-test host (where CloudKit is unavailable).
    static func makeContainer() -> ModelContainer {
        do {
            let config: ModelConfiguration
            if MygraApp.isRunningTests {
                config = ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                config = ModelConfiguration(cloudKitDatabase: .private(cloudKitContainerID))
            }
            return try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self, MigraineTag.self, IntensitySample.self,
                configurations: config
            )
        } catch {
            fatalError("[Mygra] Failed to initialize ModelContainer: \(error)")
        }
    }

    /// Process-wide shared container so the app and App Intents operate on the
    /// same store without each opening a competing CloudKit mirror.
    @MainActor static let shared: ModelContainer = makeContainer()
}
