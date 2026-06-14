//
//  SharedStatusTests.swift
//  MygraTests
//

import Foundation
import Testing
@testable import Mygra

@Suite("SharedMigraineStatus")
struct SharedStatusTests {
    @Test func roundTripThroughKeyValueStore() {
        let store = FakeKeyValueStore()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let status = SharedMigraineStatus(lastMigraineStart: start, hasOngoingMigraine: true)
        store.writeSharedStatus(status)

        let read = store.readSharedStatus()
        #expect(read.hasOngoingMigraine)
        #expect(read.lastMigraineStart.map { abs($0.timeIntervalSince(start)) < 0.001 } == true)
    }

    @Test func nilStartClearsStoredValue() {
        let store = FakeKeyValueStore()
        store.writeSharedStatus(SharedMigraineStatus(lastMigraineStart: Date(), hasOngoingMigraine: true))
        store.writeSharedStatus(SharedMigraineStatus(lastMigraineStart: nil, hasOngoingMigraine: false))

        let read = store.readSharedStatus()
        #expect(read.lastMigraineStart == nil)
        #expect(!read.hasOngoingMigraine)
    }

    @Test func legacyMillisecondValuesAreNormalized() {
        let store = FakeKeyValueStore()
        let seconds = 1_750_000_000.0
        store.set(seconds * 1000.0, forKey: SharedMigraineStatus.Keys.lastMigraineStart)

        let read = store.readSharedStatus()
        let interval = read.lastMigraineStart?.timeIntervalSince1970 ?? 0
        #expect(abs(interval - seconds) < 1.0)
    }
}
