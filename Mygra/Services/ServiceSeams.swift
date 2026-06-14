//
//  ServiceSeams.swift
//  Mygra
//
//  Protocol seams over system frameworks so managers can be unit-tested
//  with fakes. Each protocol has exactly one production conformance here.
//

import Foundation
import StoreKit
import UIKit
import WidgetKit

// MARK: - Key-value storage (UserDefaults)

/// Mirrors the `UserDefaults` methods the app uses, so `UserDefaults`
/// conforms for free and tests can substitute an in-memory fake.
protocol KeyValueStoring: AnyObject {
    func bool(forKey defaultName: String) -> Bool
    func double(forKey defaultName: String) -> Double
    func set(_ value: Bool, forKey defaultName: String)
    func set(_ value: Double, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}

extension KeyValueStoring {
    /// Reads the shared migraine status (normalizing legacy millisecond values).
    func readSharedStatus() -> SharedMigraineStatus {
        let raw = double(forKey: SharedMigraineStatus.Keys.lastMigraineStart)
        let seconds = raw > 10_000_000_000 ? raw / 1000.0 : raw
        return SharedMigraineStatus(
            lastMigraineStart: seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil,
            hasOngoingMigraine: bool(forKey: SharedMigraineStatus.Keys.hasOngoingMigraine)
        )
    }

    /// Writes the shared migraine status.
    func writeSharedStatus(_ status: SharedMigraineStatus) {
        if let start = status.lastMigraineStart {
            set(start.timeIntervalSince1970, forKey: SharedMigraineStatus.Keys.lastMigraineStart)
        } else {
            removeObject(forKey: SharedMigraineStatus.Keys.lastMigraineStart)
        }
        set(status.hasOngoingMigraine, forKey: SharedMigraineStatus.Keys.hasOngoingMigraine)
    }
}

// MARK: - Widget timeline reloading (WidgetCenter)

protocol WidgetTimelineReloading {
    func reloadTimelines(ofKind kind: String)
}

struct WidgetCenterReloader: WidgetTimelineReloading {
    nonisolated init() {}
    func reloadTimelines(ofKind kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}

// MARK: - Review requesting (StoreKit)

protocol ReviewRequesting {
    @MainActor func requestReview(in scene: UIWindowScene)
}

struct AppStoreReviewRequester: ReviewRequesting {
    nonisolated init() {}
    @MainActor func requestReview(in scene: UIWindowScene) {
        AppStore.requestReview(in: scene)
    }
}

// MARK: - Watch status pushing (WatchConnectivity, via ComplicationSync)

protocol WatchStatusPushing: AnyObject {
    func pushStatus(_ status: SharedMigraineStatus)
}
