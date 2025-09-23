//
//  FakeStore.swift
//  MygraTests
//
//  Created by Nick Molargik on 9/18/25.
//

import Foundation
import Testing
import HealthKit
@testable import Mygra

// Minimal fakes for HealthKit interactions via the Store protocol
final class FakeStore: HealthManager.Store {
    static var healthAvailable: Bool = true
    static func isHealthDataAvailable() -> Bool { healthAvailable }

    // Configurable stubs
    var readStatus: HKAuthorizationRequestStatus = .unnecessary
    var shareStatus: HKAuthorizationRequestStatus = .unnecessary
    var authStatuses: [String: HKAuthorizationStatus] = [:]

    // Query captures
    var executedQueries: [HKQuery] = []

    // Saved objects capture
    var saved: [HKObject] = []

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        // no-op; test controls statuses via `authStatuses`
    }

    func statusForAuthorizationRequest(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        if !typesToShare.isEmpty { return shareStatus } else { return readStatus }
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return authStatuses[type.identifier] ?? .sharingDenied
    }

    func execute(_ query: HKQuery) { executedQueries.append(query) }

    func save(_ object: HKObject) async throws { saved.append(object) }
}
