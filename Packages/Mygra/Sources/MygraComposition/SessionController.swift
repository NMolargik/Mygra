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
    public let attackMode: AttackModeModel
    public let cloudSyncManager: CloudSyncManager
    public let weatherManager: WeatherManager
    public let notificationManager: NotificationManager
    public let intelligence: IntelligenceService
    public let statusSync: MigraineStatusSync
    public let weatherRiskNotifier: WeatherRiskNotifier
    public let medicationNotifier: MedicationOveruseNotifier
    /// Latest MIDAS / HIT-6 answers (standard defaults).
    public let assessmentStore: ClinicalAssessmentStore
    public let subscription: SubscriptionManager
    public let paywall = PaywallPresenter()

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
    public let recordIntensitySample: any RecordIntensitySample
    public let observeMigraineChanges: any ObserveMigraineChanges

    // MARK: - App-wide state

    /// Navigation state: the selected tab and the deep link waiting to be routed (set by
    /// onOpenURL, widgets, quick actions, menu commands, and App Intents; consumed by
    /// MainView).
    public let router = AppRouter()

    /// Convenience over `router.pendingDeepLink`, kept for commands and tests.
    public var pendingDeepLink: DeepLink? {
        get { router.pendingDeepLink }
        set {
            if let newValue { router.open(newValue) } else { router.pendingDeepLink = nil }
        }
    }

    @ObservationIgnored private let indexer: (any MigraineIndexing)?
    @ObservationIgnored private let activityAnnotator: (any MigraineActivityAnnotating)?
    @ObservationIgnored private let sharedDefaults: (any KeyValueStoring)?
    @ObservationIgnored private var indexObservationTask: Task<Void, Never>?
    @ObservationIgnored private var medicationObservationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingIndexTask: Task<Void, Never>?
    @ObservationIgnored private let indexDebounce: Duration
    @ObservationIgnored private var lastIndexFingerprint: [String]?

    // MARK: - Init

    /// - Parameters:
    ///   - container: The SwiftData container (defaults to the CloudKit-backed store).
    ///   - defaults: Standard defaults (review-prompt bookkeeping).
    ///   - sharedDefaults: The App Group suite (widget/watch status, intent hand-off).
    ///   - indexer/reviewRequester/intentDonor/activityAnnotator: App-target seams (nil in tests/previews).
    ///   - subscription: The Plus entitlement source (defaults to a live StoreKit manager
    ///     caching in `defaults`; tests pass one built with `startsAutomatically: false`).
    public init(
        container: ModelContainer? = nil,
        defaults: any KeyValueStoring = UserDefaults.standard,
        sharedDefaults: (any KeyValueStoring)? = AppGroup.defaults,
        subscription: SubscriptionManager? = nil,
        indexer: (any MigraineIndexing)? = nil,
        reviewRequester: (any ReviewRequesting)? = nil,
        intentDonor: (any IntentDonating)? = nil,
        activityAnnotator: (any MigraineActivityAnnotating)? = nil,
        widgetReloader: (any WidgetTimelineReloading)? = WidgetCenterReloader(),
        indexDebounce: Duration = .milliseconds(750)
    ) {
        let container = container ?? MygraStore.makeContainer()
        self.container = container
        self.indexer = indexer
        self.activityAnnotator = activityAnnotator
        self.sharedDefaults = sharedDefaults
        self.indexDebounce = indexDebounce

        let toastManager = ToastManager()
        self.toastManager = toastManager

        let subscription = subscription ?? SubscriptionManager(defaults: defaults)
        self.subscription = subscription

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
        let recordSample = RecordIntensitySampleUseCase(repository: migraineRepository)

        self.loadMigraines = loadMigraines
        self.findMigraine = findMigraine
        self.startMigraine = startMigraine
        self.endOngoingMigraine = endOngoing
        self.recordIntensitySample = recordSample
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
            recordIntensitySample: recordSample,
            removeIntensitySample: RemoveIntensitySampleUseCase(repository: migraineRepository),
            logMedication: LogMedicationUseCase(repository: migraineRepository),
            removeMedication: RemoveMedicationUseCase(repository: migraineRepository),
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
            intelligence: intelligence,
            entitlement: subscription
        )

        let cloud = CloudSyncManager(changeCenter: changeCenter)
        cloud.configure(with: container.mainContext)
        cloudSyncManager = cloud

        let weather = WeatherManager(locationManager: LocationManager())
        weatherManager = weather
        let notifications = NotificationManager()
        notificationManager = notifications
        weatherRiskNotifier = WeatherRiskNotifier(weather: weather, notifications: notifications, entitlement: subscription)
        medicationNotifier = MedicationOveruseNotifier(notifications: notifications, defaults: defaults)
        assessmentStore = ClinicalAssessmentStore(defaults: defaults)

        let attackMode = AttackModeModel(
            migraineData: migraineData,
            startAttack: StartAttackUseCase(repository: migraineRepository, start: startMigraine),
            recordIntensity: RecordAttackIntensityUseCase(repository: migraineRepository, record: recordSample),
            logMedication: LogAttackMedicationUseCase(repository: migraineRepository, log: LogMedicationUseCase(repository: migraineRepository)),
            endAttack: EndAttackUseCase(repository: migraineRepository, end: endOngoing),
            coordinator: FinishLoggingCoordinator(defaults: defaults, scheduler: notifications),
            observeChanges: observeChanges,
            toastManager: toastManager
        )
        self.attackMode = attackMode

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
            start: startMigraine,
            attack: attackMode
        )
        #endif

        startIndexObservation()
    }

    deinit {
        indexObservationTask?.cancel()
        medicationObservationTask?.cancel()
        pendingIndexTask?.cancel()
    }

    /// Whether a migraine is in progress (menu-bar command state).
    public var hasOngoingMigraine: Bool { migraineData.ongoingMigraine != nil }

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
        startMedicationObservation()
    }

    /// Re-checks medication-overuse levels at launch and after every store change. The
    /// notifier's ledger makes each crossing alert only once.
    private func startMedicationObservation() {
        guard medicationObservationTask == nil else { return }
        medicationObservationTask = Task { [weak self] in
            await self?.checkMedicationOveruse()
            guard let stream = self?.observeMigraineChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                await self.checkMedicationOveruse()
            }
        }
    }

    /// One overuse evaluation over the stored migraines.
    public func checkMedicationOveruse() async {
        guard let migraines = try? loadMigraines() else { return }
        await medicationNotifier.checkAndNotify(migraines: migraines)
    }

    /// Runs one weather-risk check (background task or foreground timer). A no-op
    /// without Mygra Plus.
    public func checkWeatherRisk() async {
        await weatherRiskNotifier.checkAndNotify()
    }

    /// Shows the one-time early-supporter thank-you once the grandfather check has
    /// landed. Safe to call on every activation; it fires at most once per install.
    public func showEarlySupporterThanksIfNeeded() {
        guard subscription.shouldShowEarlySupporterThanks else { return }
        subscription.markEarlySupporterThanksShown()
        toastManager.show(
            message: String(localized: "Thanks for being an early supporter — Mygra Plus is yours for life."),
            style: .success,
            icon: "sparkles"
        )
    }

    // MARK: - Deep links

    /// Parses and stages an external URL (`mygra://…`); MainView consumes it.
    public func handle(url: URL) {
        router.open(url: url)
    }

    /// Starts an attack when none is active, then shows Attack Mode (the Action button /
    /// Siri intent; widgets and the Control arrive as `mygra://attack-mode`).
    public func enterAttackMode() {
        attackMode.enter()
    }

    /// Call when the app becomes active: picks up intent hand-offs and re-asserts the
    /// Live Activity (an attack started from the watch while the app was suspended could
    /// not start one).
    public func appDidBecomeActive() {
        consumePendingDeepLinkFromIntents()
        statusSync.reassertLiveActivity()
    }

    /// Picks up a deep link stashed by an `openAppWhenRun` App Intent.
    public func consumePendingDeepLinkFromIntents() {
        if let link = DeepLink.takePending(from: sharedDefaults) {
            router.open(link)
        }
    }

    // MARK: - Siri on-screen awareness

    /// Publishes the detail screen's user activity, tagged with the migraine's entity
    /// identifier so Siri can act on "this migraine". Safe without an annotator (tests).
    public func annotateViewingActivity(_ activity: NSUserActivity, migraineID: UUID) {
        activity.title = String(localized: "Migraine")
        activity.isEligibleForHandoff = false
        activity.isEligibleForSearch = false
        activity.userInfo = ["migraineID": migraineID.uuidString]
        activityAnnotator?.annotate(activity, migraineID: migraineID)
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
