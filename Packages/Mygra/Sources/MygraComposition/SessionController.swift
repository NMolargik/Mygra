//
//  SessionController.swift
//  MygraComposition
//
//  The composition root. Builds the whole dependency graph once (container → change
//  center → repositories → use-cases → shared models → system-framework managers →
//  cross-process status sync) and owns app-wide policy: deep-link state, Spotlight
//  reindexing, weather-risk checks, and startup work. Screens read the shared
//  @Observable models from the environment (RootView injects them); App Intents reach
//  persistence through the use-case properties — never a repository directly.
//

import Foundation
import Observation
import SwiftData
import MygraCore
import MygraData
import MygraDesignSystem
import MygraFeatureShared
import MygraServices
import os

@MainActor
@Observable
public final class SessionController {

    // MARK: - Graph

    public let container: ModelContainer
    public let toastManager: ToastManager
    public let migraineData: MigraineDataModel
    public let tagData: TagDataModel
    public let userData: UserDataModel
    public let insights: InsightModel
    public let cloudSyncManager: CloudSyncManager
    public let weatherManager: WeatherManager
    public let notificationManager: NotificationManager
    public let intelligence: IntelligenceService
    public let statusSync: MigraineStatusSync
    public let weatherRiskNotifier: WeatherRiskNotifier

    #if canImport(HealthKit) && !os(macOS)
    public let healthManager: HealthManager
    #endif
    #if canImport(WatchConnectivity)
    public let phoneConnectivity: PhoneConnectivityManager
    #endif

    // Use-cases exposed for App Intents and Spotlight.
    public let loadMigraines: any LoadMigraines
    public let findMigraine: any FindMigraine
    public let startMigraine: any StartMigraine
    public let endOngoingMigraine: any EndOngoingMigraine
    public let observeMigraineChanges: any ObserveMigraineChanges

    // MARK: - App-wide state

    /// Deep link waiting to be routed (set by onOpenURL, widgets, menu commands, and
    /// App Intents; consumed by MainView).
    public var pendingDeepLink: DeepLink?

    @ObservationIgnored private let indexer: (any MigraineIndexing)?
    @ObservationIgnored private let sharedDefaults: (any KeyValueStoring)?
    @ObservationIgnored private var indexObservationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingIndexTask: Task<Void, Never>?
    @ObservationIgnored private let indexDebounce: Duration
    @ObservationIgnored private var lastIndexFingerprint: [String]?

    // MARK: - Init

    /// - Parameters:
    ///   - container: The SwiftData container (defaults to the CloudKit-backed store).
    ///   - defaults: Standard defaults (review-prompt bookkeeping).
    ///   - sharedDefaults: The App Group suite (widget/watch status, intent hand-off).
    ///   - indexer/reviewRequester/intentDonor: App-target seams (nil in tests/previews).
    public init(
        container: ModelContainer? = nil,
        defaults: any KeyValueStoring = UserDefaults.standard,
        sharedDefaults: (any KeyValueStoring)? = AppGroup.defaults,
        indexer: (any MigraineIndexing)? = nil,
        reviewRequester: (any ReviewRequesting)? = nil,
        intentDonor: (any IntentDonating)? = nil,
        widgetReloader: (any WidgetTimelineReloading)? = WidgetCenterReloader(),
        indexDebounce: Duration = .milliseconds(750)
    ) {
        let container = container ?? MygraStore.makeContainer()
        self.container = container
        self.indexer = indexer
        self.sharedDefaults = sharedDefaults
        self.indexDebounce = indexDebounce

        let toastManager = ToastManager()
        self.toastManager = toastManager

        let changeCenter = MigraineChangeCenter()
        let migraineRepository = DefaultMigraineRepository(container: container, changeCenter: changeCenter)
        let tagRepository = DefaultTagRepository(container: container, changeCenter: changeCenter)
        let userRepository = DefaultUserRepository(container: container, changeCenter: changeCenter)

        #if canImport(HealthKit) && !os(macOS)
        let health = HealthManager()
        healthManager = health
        let headaches: (any HeadacheRecording)? = health
        #else
        let headaches: (any HeadacheRecording)? = nil
        #endif

        let loadMigraines = LoadMigrainesUseCase(repository: migraineRepository)
        let findMigraine = FindMigraineUseCase(repository: migraineRepository)
        let logMigraine = LogMigraineUseCase(repository: migraineRepository, headaches: headaches, donor: intentDonor)
        let startMigraine = StartMigraineUseCase(repository: migraineRepository, log: logMigraine)
        let updateMigraine = UpdateMigraineUseCase(repository: migraineRepository, headaches: headaches)
        let endOngoing = EndOngoingMigraineUseCase(repository: migraineRepository, update: updateMigraine, donor: intentDonor)
        let observeChanges = ObserveMigraineChangesUseCase(center: changeCenter)
        let loadUser = LoadUserUseCase(repository: userRepository)

        self.loadMigraines = loadMigraines
        self.findMigraine = findMigraine
        self.startMigraine = startMigraine
        self.endOngoingMigraine = endOngoing
        self.observeMigraineChanges = observeChanges

        #if DEBUG
        let sampleData: (any GenerateSampleData)? = SampleMigraineData(migraines: migraineRepository, tags: tagRepository)
        #else
        let sampleData: (any GenerateSampleData)? = nil
        #endif

        migraineData = MigraineDataModel(
            loadMigraines: loadMigraines,
            findMigraine: findMigraine,
            countMigraines: CountMigrainesUseCase(repository: migraineRepository),
            logMigraine: logMigraine,
            startMigraine: startMigraine,
            updateMigraine: updateMigraine,
            endOngoing: endOngoing,
            deleteMigraine: DeleteMigraineUseCase(repository: migraineRepository),
            deleteAll: DeleteAllMigrainesUseCase(repository: migraineRepository),
            recordIntensitySample: RecordIntensitySampleUseCase(repository: migraineRepository),
            removeIntensitySample: RemoveIntensitySampleUseCase(repository: migraineRepository),
            observeChanges: observeChanges,
            reviewRequester: reviewRequester,
            defaults: defaults,
            generateSampleData: sampleData,
            toastManager: toastManager
        )

        tagData = TagDataModel(
            loadTags: LoadTagsUseCase(repository: tagRepository),
            createTag: CreateTagUseCase(repository: tagRepository),
            updateTag: UpdateTagUseCase(repository: tagRepository),
            deleteTag: DeleteTagUseCase(repository: tagRepository),
            reorderTags: ReorderTagsUseCase(repository: tagRepository),
            assignTags: AssignTagsUseCase(repository: tagRepository),
            observeChanges: observeChanges,
            toastManager: toastManager
        )

        userData = UserDataModel(
            loadUser: loadUser,
            saveUser: SaveUserUseCase(repository: userRepository),
            updateUser: UpdateUserUseCase(repository: userRepository),
            deleteUser: DeleteUserUseCase(repository: userRepository),
            observeChanges: observeChanges,
            toastManager: toastManager
        )

        let intelligence = IntelligenceService()
        self.intelligence = intelligence
        insights = InsightModel(
            loadMigraines: loadMigraines,
            findMigraine: findMigraine,
            loadUser: loadUser,
            updateMigraine: updateMigraine,
            observeChanges: observeChanges,
            intelligence: intelligence
        )

        let cloud = CloudSyncManager(changeCenter: changeCenter)
        cloud.configure(with: container.mainContext)
        cloudSyncManager = cloud

        let weather = WeatherManager(locationManager: LocationManager())
        weatherManager = weather
        let notifications = NotificationManager()
        notificationManager = notifications
        weatherRiskNotifier = WeatherRiskNotifier(weather: weather, notifications: notifications)

        #if canImport(WatchConnectivity)
        let phone = PhoneConnectivityManager()
        phoneConnectivity = phone
        let watch: (any WatchStatusPushing)? = phone
        #else
        let watch: (any WatchStatusPushing)? = nil
        #endif

        #if canImport(ActivityKit) && os(iOS)
        let liveActivity: (any MigraineActivityControlling)? = LiveActivityController()
        #else
        let liveActivity: (any MigraineActivityControlling)? = nil
        #endif

        let statusSync = MigraineStatusSync(
            loadMigraines: loadMigraines,
            observeChanges: observeChanges,
            sharedDefaults: sharedDefaults,
            widgets: widgetReloader,
            watch: watch,
            liveActivity: liveActivity
        )
        self.statusSync = statusSync

        #if canImport(WatchConnectivity)
        phone.configure(
            currentStatus: { [statusSync] in statusSync.currentStatus() },
            endOngoing: endOngoing,
            start: startMigraine
        )
        #endif

        startIndexObservation()
    }

    deinit {
        indexObservationTask?.cancel()
        pendingIndexTask?.cancel()
    }

    // MARK: - Startup

    /// One-time launch work: status sync, watch connectivity, Spotlight seeding, and the
    /// intent hand-off check. Safe to call more than once.
    public func start() {
        statusSync.start()
        #if canImport(WatchConnectivity)
        phoneConnectivity.activate()
        #endif
        reindexMigraines()
        consumePendingDeepLinkFromIntents()
    }

    /// Runs one weather-risk check (background task or foreground timer).
    public func checkWeatherRisk() async {
        await weatherRiskNotifier.checkAndNotify()
    }

    // MARK: - Deep links

    /// Parses and stages an external URL (`mygra://…`); MainView consumes it.
    public func handle(url: URL) {
        guard let link = DeepLink(url: url) else { return }
        pendingDeepLink = link
    }

    /// Picks up a deep link stashed by an `openAppWhenRun` App Intent (call on activation).
    public func consumePendingDeepLinkFromIntents() {
        if let link = DeepLink.takePending(from: sharedDefaults) {
            pendingDeepLink = link
        }
    }

    // MARK: - Spotlight

    /// Rebuilds the semantic migraine index unconditionally (launch seeding).
    public func reindexMigraines() {
        guard let indexer else { return }
        do {
            let migraines = try loadMigraines()
            lastIndexFingerprint = Self.indexFingerprint(of: migraines)
            indexer.reindex(migraines: migraines)
        } catch {
            Log.spotlight.error("Reindex fetch failed: \(error.localizedDescription)")
        }
    }

    /// Rebuilds the index only when an indexed field actually changed.
    func reindexMigrainesIfNeeded() {
        guard let indexer else { return }
        do {
            let migraines = try loadMigraines()
            let fingerprint = Self.indexFingerprint(of: migraines)
            guard fingerprint != lastIndexFingerprint else {
                Log.spotlight.debug("Spotlight index unchanged; skipping reindex")
                return
            }
            lastIndexFingerprint = fingerprint
            indexer.reindex(migraines: migraines)
        } catch {
            Log.spotlight.error("Reindex fetch failed: \(error.localizedDescription)")
        }
    }

    /// Mirrors the fields the app-target entity publishes to Spotlight.
    private static func indexFingerprint(of migraines: [Migraine]) -> [String] {
        migraines.map { migraine in
            "\(migraine.id)|\(migraine.startDate.timeIntervalSince1970)|\(migraine.endDate?.timeIntervalSince1970 ?? 0)|\(migraine.painLevel)|\(migraine.note ?? "")|\(migraine.allTriggerNames.joined(separator: ","))"
        }
    }

    private func startIndexObservation() {
        guard indexer != nil else { return }
        indexObservationTask = Task { [weak self] in
            guard let stream = self?.observeMigraineChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                self.scheduleReindex()
            }
        }
    }

    /// Coalesces a burst of change events into one reindex after `indexDebounce`.
    private func scheduleReindex() {
        pendingIndexTask?.cancel()
        pendingIndexTask = Task { [weak self, indexDebounce] in
            do {
                try await Task.sleep(for: indexDebounce)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.pendingIndexTask = nil
            self.reindexMigrainesIfNeeded()
        }
    }
}
