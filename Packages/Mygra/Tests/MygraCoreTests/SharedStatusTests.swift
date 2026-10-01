//
//  SharedStatusTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("SharedMigraineStatus")
struct SharedStatusTests {
    @Test func roundTripThroughKeyValueStore() {
        let store = FakeKeyValueStore()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        store.writeSharedStatus(SharedMigraineStatus(lastMigraineStart: start, hasOngoingMigraine: true))

        let read = store.readSharedStatus()
        #expect(read.hasOngoingMigraine)
        #expect(read.lastMigraineStart.map { abs($0.timeIntervalSince(start)) < 0.001 } == true)
    }

    @Test func nilStartClearsStoredValue() {
        let store = FakeKeyValueStore()
        store.writeSharedStatus(SharedMigraineStatus(lastMigraineStart: Date(), hasOngoingMigraine: true))
        store.writeSharedStatus(.empty)
        let read = store.readSharedStatus()
        #expect(read.lastMigraineStart == nil)
        #expect(!read.hasOngoingMigraine)
    }

    @Test func legacyMillisecondValuesAreNormalized() {
        let store = FakeKeyValueStore()
        let seconds = 1_750_000_000.0
        store.set(seconds * 1000.0, forKey: SharedMigraineStatus.Keys.lastMigraineStart)
        let interval = store.readSharedStatus().lastMigraineStart?.timeIntervalSince1970 ?? 0
        #expect(abs(interval - seconds) < 1.0)
    }

    @Test func wirePayloadRoundTrips() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let status = SharedMigraineStatus(lastMigraineStart: start, hasOngoingMigraine: true)
        let decoded = try #require(SharedMigraineStatus(payload: status.payload))
        #expect(decoded == status)
        #expect(SharedMigraineStatus(payload: [:]) == nil)
        #expect(SharedMigraineStatus(payload: SharedMigraineStatus.empty.payload) == .empty)
    }
}
