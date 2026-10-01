//
//  MygraStore.swift
//  MygraData
//
//  Builds the SwiftData container, degrading gracefully when CloudKit is unavailable:
//  CloudKit-synced → local-only → in-memory (the old app fatal-errored). No fatalError
//  short of a machine that can't allocate memory.
//

import Foundation
import SwiftData
import MygraCore
import os

public enum MygraStore {

    public static let cloudKitContainerID = "iCloud.com.molargiksoftware.Mygra"

    /// The model types persisted by the app.
    public static let schema = Schema([
        User.self,
        Migraine.self,
        WeatherData.self,
        HealthData.self,
        MigraineTag.self,
        IntensitySample.self,
    ])

    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            do {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: memory)
            } catch {
                fatalError("Failed to create an in-memory ModelContainer: \(error)")
            }
        }

        do {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
            return try ModelContainer(for: schema, configurations: cloud)
        } catch {
            Log.app.error("CloudKit container unavailable, falling back to local store: \(error.localizedDescription)")
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            Log.app.fault("Local store unavailable, falling back to in-memory: \(error.localizedDescription)")
        }

        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
        } catch {
            fatalError("Failed to create even an in-memory ModelContainer: \(error)")
        }
    }

    /// A container backed by a unique on-disk temp store: the shape tests and previews
    /// need (parallel in-memory containers share a /dev/null SQLite identity).
    public static func makeTemporaryContainer() throws -> ModelContainer {
        let url = URL.temporaryDirectory.appending(path: "mygra-\(UUID().uuidString).store")
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }
}
