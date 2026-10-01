//
//  CloudSyncManager.swift
//  MygraServices
//
//  Monitors iCloud/CloudKit sync status for SwiftData. SwiftData's CloudKit mirroring is
//  powered by NSPersistentCloudKitContainer, so this listens to that container's real
//  event stream (setup/import/export with errors) plus remote-change pings, and relays
//  imports into the migraine change stream so screens refresh mid-session.
//

import Foundation
import SwiftData
import CoreData
import Network
import Observation
import MygraCore
import os

@MainActor @Observable
public final class CloudSyncManager {

    // MARK: - Sync Status

    public enum SyncStatus: Equatable, Sendable {
        case idle
        case syncing
        case synced(Date)
        case error(String)
        case offline
        /// No iCloud account is signed in on this device, so nothing can sync.
        case unavailable

        public var displayText: String {
            switch self {
            case .idle: return String(localized: "Ready")
            case .syncing: return String(localized: "Syncing...")
            case .synced(let date): return String(localized: "Last synced \(date.formatted(.relative(presentation: .named)))")
            case .error(let message): return String(localized: "Error: \(message)")
            case .offline: return String(localized: "Offline")
            case .unavailable: return String(localized: "Not signed in to iCloud")
            }
        }

        /// Whether this status represents a failure the user may want to act on.
        public var isError: Bool {
            if case .error = self { return true }
            return false
        }

        /// A short, stable status label for pills and accessibility values.
        public var shortText: String {
            switch self {
            case .idle: return String(localized: "Ready")
            case .syncing: return String(localized: "Syncing")
            case .synced: return String(localized: "Up to date")
            case .error: return String(localized: "Needs attention")
            case .offline: return String(localized: "Offline")
            case .unavailable: return String(localized: "Not signed in")
            }
        }

        public var systemImage: String {
            switch self {
            case .idle: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .offline: return "icloud.slash"
            case .unavailable: return "person.icloud"
            }
        }
    }

    // MARK: - Properties

    public private(set) var syncStatus: SyncStatus = .idle
    public private(set) var isSyncing: Bool = false
    public private(set) var lastSyncDate: Date?
    public private(set) var hasReceivedRemoteChange: Bool = false
    /// The last CloudKit event error, if any (cleared by the next success).
    public private(set) var lastErrorMessage: String?

    @ObservationIgnored private let changeCenter: MigraineChangeCenter?
    @ObservationIgnored private let cloudAvailability: @MainActor () -> Bool
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var networkMonitor: NWPathMonitor?
    @ObservationIgnored private var isNetworkAvailable: Bool = true
    @ObservationIgnored private var notificationObservers: [any NSObjectProtocol] = []

    // MARK: - Initialization

    /// - Parameters:
    ///   - changeCenter: Receives `.bulk` on every CloudKit import.
    ///   - cloudAvailability: Whether an iCloud account is signed in (injectable for tests;
    ///     defaults to the ubiquity identity token check).
    public init(
        changeCenter: MigraineChangeCenter? = nil,
        cloudAvailability: @escaping @MainActor () -> Bool = { FileManager.default.ubiquityIdentityToken != nil }
    ) {
        self.changeCenter = changeCenter
        self.cloudAvailability = cloudAvailability
    }

    public func configure(with context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        startMonitoring()
    }

    public func cleanup() {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor in
                self?.handleNetworkChange(isAvailable: isAvailable)
            }
        }
        monitor.start(queue: DispatchQueue(label: "CloudSyncNetworkMonitor"))
        networkMonitor = monitor

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
    nonisolated struct CloudEventSnapshot: Sendable {
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

        init(isImport: Bool, isFinished: Bool, succeeded: Bool, errorDescription: String?) {
            self.isImport = isImport
            self.isFinished = isFinished
            self.succeeded = succeeded
            self.errorDescription = errorDescription
        }
    }

    // MARK: - Event Handlers

    func handleCloudEvent(_ event: CloudEventSnapshot) {
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

    func handleNetworkChange(isAvailable: Bool) {
        isNetworkAvailable = isAvailable
        updateSyncStatus()
    }

    func handleRemoteChange() {
        lastSyncDate = Date()
        markRemoteChangeReceived()
        updateSyncStatus()
    }

    private func markRemoteChangeReceived() {
        hasReceivedRemoteChange = true
        // Screens observe one multicast stream; CloudKit imports flow into it too.
        changeCenter?.notify(.bulk)
    }

    private func updateSyncStatus() {
        if !isNetworkAvailable {
            syncStatus = .offline
        } else if !isCloudAvailable {
            syncStatus = .unavailable
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

    /// How long a manual sync waits for the CloudKit event stream to settle.
    public var manualSyncTimeout: Duration = .seconds(6)

    /// Saves pending changes (which schedules a CloudKit export) and waits for the
    /// resulting event stream to settle — up to `manualSyncTimeout` — so the Settings
    /// row can show a truthful "Last synced" time rather than a fixed delay.
    public func triggerSync() async {
        guard isNetworkAvailable else {
            syncStatus = .offline
            return
        }
        guard isCloudAvailable else {
            syncStatus = .unavailable
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
            // Give CloudKit a moment to start an export, then wait for it to finish.
            let deadline = ContinuousClock.now.advanced(by: manualSyncTimeout)
            try await Task.sleep(for: .milliseconds(300))
            while isSyncing, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(150))
            }
            if !isSyncing, lastErrorMessage == nil {
                lastSyncDate = Date()
            }
            updateSyncStatus()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    /// Whether an iCloud account is signed in on this device.
    public var isCloudAvailable: Bool {
        cloudAvailability()
    }

    /// Whether the network is reachable (also drives the Settings delete gate).
    public var isOnline: Bool { isNetworkAvailable }

    // MARK: - Initial Sync Waiting

    /// Waits for a remote change or timeout, whichever comes first. Polls the flag so no
    /// continuation can leak on timeout.
    public func waitForRemoteChange(timeout: TimeInterval, pollInterval: Duration = .milliseconds(200)) async -> Bool {
        if hasReceivedRemoteChange { return true }
        guard isCloudAvailable && isNetworkAvailable else { return false }

        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while ContinuousClock.now < deadline {
            if hasReceivedRemoteChange { return true }
            do {
                try await Task.sleep(for: pollInterval)
            } catch {
                return hasReceivedRemoteChange
            }
        }
        return hasReceivedRemoteChange
    }

    public func resetRemoteChangeTracking() {
        hasReceivedRemoteChange = false
    }
}
