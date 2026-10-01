//
//  CloudSyncManagerTests.swift
//  MygraServicesTests
//

import Foundation
import Testing
import MygraCore
@testable import MygraServices

@Suite("CloudSyncManager")
@MainActor
struct CloudSyncManagerTests {
    @Test func startsIdleAndUnsynced() {
        let sut = CloudSyncManager(cloudAvailability: { true })
        #expect(sut.syncStatus == .idle)
        #expect(!sut.hasReceivedRemoteChange)
        #expect(sut.lastSyncDate == nil)
    }

    @Test func offlineTakesPrecedence() {
        let sut = CloudSyncManager(cloudAvailability: { true })
        sut.handleNetworkChange(isAvailable: false)
        #expect(sut.syncStatus == .offline)
        #expect(!sut.isOnline)
        sut.handleNetworkChange(isAvailable: true)
        #expect(sut.syncStatus == .idle)
    }

    @Test func importEventsRelayIntoTheChangeStream() async {
        let center = MigraineChangeCenter()
        let sut = CloudSyncManager(changeCenter: center, cloudAvailability: { true })
        var iterator = center.changes().makeAsyncIterator()

        sut.handleCloudEvent(.init(isImport: true, isFinished: false, succeeded: false, errorDescription: nil))
        #expect(sut.syncStatus == .syncing)

        sut.handleCloudEvent(.init(isImport: true, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(sut.hasReceivedRemoteChange)
        if case .synced = sut.syncStatus {} else { Issue.record("expected synced, got \(sut.syncStatus)") }
        #expect(await iterator.next() == .bulk)
    }

    @Test func failedEventsSurfaceTheError() {
        let sut = CloudSyncManager(cloudAvailability: { true })
        sut.handleCloudEvent(.init(isImport: false, isFinished: true, succeeded: false, errorDescription: "quota"))
        #expect(sut.syncStatus == .error("quota"))
        #expect(sut.lastErrorMessage == "quota")

        sut.handleCloudEvent(.init(isImport: false, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(sut.lastErrorMessage == nil)
    }

    @Test func remoteChangeMarksAndResets() {
        let sut = CloudSyncManager(cloudAvailability: { true })
        sut.handleRemoteChange()
        #expect(sut.hasReceivedRemoteChange)
        sut.resetRemoteChangeTracking()
        #expect(!sut.hasReceivedRemoteChange)
    }

    @Test func manualSyncReportsOfflineWithoutTouchingTheStore() async {
        let sut = CloudSyncManager(cloudAvailability: { true })
        sut.handleNetworkChange(isAvailable: false)
        await sut.triggerSync()
        #expect(sut.syncStatus == .offline)
        #expect(sut.lastSyncDate == nil)
    }

    @Test func statusLabelsCoverEveryCase() {
        #expect(CloudSyncManager.SyncStatus.error("x").isError)
        #expect(!CloudSyncManager.SyncStatus.idle.isError)
        #expect(!CloudSyncManager.SyncStatus.synced(Date()).shortText.isEmpty)
        #expect(CloudSyncManager.SyncStatus.syncing.systemImage == "arrow.triangle.2.circlepath.icloud")
    }

    @Test func signedOutDevicesReportUnavailableInsteadOfErrors() async {
        let sut = CloudSyncManager(cloudAvailability: { false })
        sut.handleCloudEvent(.init(isImport: false, isFinished: true, succeeded: false, errorDescription: "no account"))
        #expect(sut.syncStatus == .unavailable)
        #expect(!sut.isCloudAvailable)
        await sut.triggerSync()
        #expect(sut.syncStatus == .unavailable)
        #expect(sut.syncStatus.systemImage == "person.icloud")
    }
}
