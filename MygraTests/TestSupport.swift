//
//  TestSupport.swift
//  MygraTests
//
//  Shared fixtures: isolated SwiftData containers and test doubles for
//  every service seam.
//

import Foundation
import SwiftData
import UIKit
@testable import Mygra

// MARK: - Isolated model containers

/// Creates a SwiftData container backed by a unique on-disk temp store.
///
/// In-memory containers all share a `/dev/null` SQLite identity, which makes
/// parallel Swift Testing suites trample each other inside CoreData's
/// connection manager. A unique on-disk URL per container avoids that;
/// suites that create containers are additionally marked `.serialized`.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let url = URL.temporaryDirectory.appending(path: "mygra-test-\(UUID().uuidString).store")
    let config = ModelConfiguration(url: url)
    return try ModelContainer(
        for: User.self, Migraine.self, WeatherData.self, HealthData.self, MigraineTag.self, IntensitySample.self,
        configurations: config
    )
}

// MARK: - Migraine fixtures

@MainActor
@discardableResult
func makeMigraine(
    in context: ModelContext,
    start: Date = Date(),
    end: Date? = nil,
    pain: Int = 5,
    stress: Int = 5,
    note: String? = nil,
    triggers: [MigraineTrigger] = [],
    customTriggers: [String] = [],
    foods: [String] = []
) -> Migraine {
    let migraine = Migraine(
        startDate: start,
        endDate: end,
        painLevel: pain,
        stressLevel: stress,
        note: note,
        triggers: triggers,
        customTriggers: customTriggers,
        foodsEaten: foods
    )
    context.insert(migraine)
    return migraine
}

// MARK: - Test doubles for service seams

final class FakeKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private(set) var storage: [String: Any] = [:]

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func double(forKey defaultName: String) -> Double {
        storage[defaultName] as? Double ?? 0
    }

    func set(_ value: Bool, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func set(_ value: Double, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}

final class FakeWidgetReloader: WidgetTimelineReloading, @unchecked Sendable {
    private(set) var reloadedKinds: [String] = []

    func reloadTimelines(ofKind kind: String) {
        reloadedKinds.append(kind)
    }
}

final class FakeReviewRequester: ReviewRequesting, @unchecked Sendable {
    private(set) var requestCount = 0

    @MainActor func requestReview(in scene: UIWindowScene) {
        requestCount += 1
    }
}

final class FakeWatchPusher: WatchStatusPushing, @unchecked Sendable {
    private(set) var pushedStatuses: [SharedMigraineStatus] = []

    func pushStatus(_ status: SharedMigraineStatus) {
        pushedStatuses.append(status)
    }
}
