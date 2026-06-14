//
//  CloudSyncManager.swift
//  Mygra
//
//  Created by Nick Molargik on 1/20/26.
//

import Foundation
import SwiftData
import CoreData
import Network
import os

/// Manages and monitors iCloud/CloudKit sync status for SwiftData.
///
/// SwiftData's CloudKit mirroring is powered by NSPersistentCloudKitContainer
/// under the hood, so this manager listens to that container's real event
/// stream (`eventChangedNotification`: setup/import/export with success or
/// error) instead of guessing from timers.
@MainActor @Observable
final class CloudSyncManager {

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case error(String)
        case offline

        var displayText: String {
            switch self {
            case .idle:
                return String(localized: "Ready")
            case .syncing:
                return String(localized: "Syncing...")
            case .synced(let date):
                return String(localized: "Last synced \(date.formatted(.relative(presentation: .named)))")
            case .error(let message):
                return String(localized: "Error: \(message)")
            case .offline:
                return String(localized: "Offline")
            }
        }

        var systemImage: String {
            switch self {
            case .idle: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .offline: return "icloud.slash"
            }
        }

        var color: String {
            switch self {
            case .idle: return "secondary"
            case .syncing: return "blue"
            case .synced: return "green"
            case .error: return "red"
            case .offline: return "orange"
            }
        }
    }

    // MARK: - Properties

    private(set) var syncStatus: SyncStatus = .idle
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var hasReceivedRemoteChange: Bool = false
    /// The last CloudKit event error, if any (cleared by the next success).
    private(set) var lastErrorMessage: String?

    /// Invoked on the main actor whenever CloudKit delivers a remote change,
    /// so the app can refresh in-memory caches mid-session (no blocking screen).
    @ObservationIgnored var onRemoteChange: (() -> Void)?

    private var modelContext: ModelContext?
    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable: Bool = true
    private var notificationObservers: [any NSObjectProtocol] = []
    /// Continuations from waitForRemoteChange(timeout:), resumed exactly once each.
    private var remoteChangeContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    // MARK: - Initialization

    init() {}

    func configure(with context: ModelContext) {
        guard modelContext == nil else { return }
        self.modelContext = context
        startMonitoring()
    }

    func cleanup() {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Monitor network status
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor in
                self?.handleNetworkChange(isAvailable: isAvailable)
            }
        }
        monitor.start(queue: DispatchQueue(label: "CloudSyncNetworkMonitor"))
        self.networkMonitor = monitor

        // Remote-change pings (another device pushed data into our store)
        let remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleRemoteChange()
            }
        }
        notificationObservers.append(remoteChangeObserver)

        // Real CloudKit sync events: setup, import, export — with errors.
        let eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
            let snapshot = CloudEventSnapshot(event)
            Task { @MainActor in
                self?.handleCloudEvent(snapshot)
            }
        }
        notificationObservers.append(eventObserver)

        updateSyncStatus()
    }

    private func stopMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil

        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    /// Sendable snapshot of the fields we need from a CloudKit container event.
    private nonisolated struct CloudEventSnapshot: Sendable {
        let isImport: Bool
        let isFinished: Bool
        let succeeded: Bool
        let errorDescription: String?

        init(_ event: NSPersistentCloudKitContainer.Event) {
            isImport = event.type == .import
            isFinished = event.endDate != nil
            succeeded = event.succeeded
            errorDescription = event.error?.localizedDescription
        }
    }

    // MARK: - Event Handlers

    private func handleCloudEvent(_ event: CloudEventSnapshot) {
        if !event.isFinished {
            isSyncing = true
        } else {
            isSyncing = false
            if event.succeeded {
                lastSyncDate = Date()
                lastErrorMessage = nil
                if event.isImport {
                    markRemoteChangeReceived()
                }
            } else if let message = event.errorDescription {
                lastErrorMessage = message
                Log.sync.error("CloudKit sync event failed: \(message)")
            }
        }
        updateSyncStatus()
    }

    private func handleNetworkChange(isAvailable: Bool) {
        isNetworkAvailable = isAvailable
        updateSyncStatus()
    }

    private func handleRemoteChange() {
        lastSyncDate = Date()
        markRemoteChangeReceived()
        updateSyncStatus()
    }

    private func markRemoteChangeReceived() {
        hasReceivedRemoteChange = true
        // Resume all waiters exactly once.
        let continuations = remoteChangeContinuations
        remoteChangeContinuations.removeAll()
        for continuation in continuations.values {
            continuation.resume()
        }
        // Notify the app so it can refresh caches mid-session.
        onRemoteChange?()
    }

    private func updateSyncStatus() {
        if !isNetworkAvailable {
            syncStatus = .offline
        } else if isSyncing {
            syncStatus = .syncing
        } else if let message = lastErrorMessage {
            syncStatus = .error(message)
        } else if let lastSync = lastSyncDate {
            syncStatus = .synced(lastSync)
        } else {
            syncStatus = .idle
        }
    }

    // MARK: - Manual Sync

    /// Saves pending changes (which schedules a CloudKit export) and briefly
    /// waits for the resulting event stream to settle.
    func triggerSync() async {
        guard isNetworkAvailable else {
            syncStatus = .offline
            return
        }

        guard let context = modelContext else {
            syncStatus = .error(String(localized: "Not configured"))
            return
        }

        do {
            if context.hasChanges {
                try context.save()
            }
            // The eventChangedNotification observer flips isSyncing/synced as
            // the export progresses; give it a moment to start reporting.
            try await Task.sleep(for: .milliseconds(500))
            if !isSyncing, lastErrorMessage == nil {
                lastSyncDate = Date()
            }
            updateSyncStatus()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    /// Checks if iCloud is available on this device
    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Initial Sync Waiting

    /// Waits for a remote change notification or timeout, whichever comes first.
    /// Returns `true` if a remote change was received, `false` if timed out.
    func waitForRemoteChange(timeout: TimeInterval) async -> Bool {
        // If we've already received a remote change, return immediately
        if hasReceivedRemoteChange {
            return true
        }

        // If iCloud isn't available, don't wait
        guard isCloudAvailable && isNetworkAvailable else {
            return false
        }

        let id = UUID()
        // Schedule the timeout; if it fires first, resume the pending
        // continuation (exactly once — it is removed from the table on resume).
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            self?.resumeWaiter(id: id)
        }

        await withCheckedContinuation { continuation in
            remoteChangeContinuations[id] = continuation
        }
        timeoutTask.cancel()

        return hasReceivedRemoteChange
    }

    private func resumeWaiter(id: UUID) {
        if let continuation = remoteChangeContinuations.removeValue(forKey: id) {
            continuation.resume()
        }
    }

    /// Resets the remote change tracking (useful for testing or re-checking)
    func resetRemoteChangeTracking() {
        hasReceivedRemoteChange = false
    }
}
