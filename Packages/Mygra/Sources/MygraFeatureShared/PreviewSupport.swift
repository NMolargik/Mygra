//
//  PreviewSupport.swift
//  MygraFeatureShared
//
//  One-stop dependency graph for SwiftUI previews: in-memory repositories (no SwiftData,
//  no CloudKit) behind the same use-cases production uses, plus every environment
//  object feature views read. Previews are the only place outside the composition root
//  where the shared models are constructed.
//

#if DEBUG
import Foundation
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices

// MARK: - In-memory repositories

@MainActor
public final class PreviewMigraineRepository: MigraineRepository {
    public var storage: [Migraine]
    public let changeCenter: MigraineChangeCenter

    public init(storage: [Migraine] = [], changeCenter: MigraineChangeCenter = MigraineChangeCenter()) {
        self.storage = storage
        self.changeCenter = changeCenter
    }

    public func migraines() throws(PersistenceError) -> [Migraine] { storage.sorted { $0.startDate > $1.startDate } }
    public func migraine(withID id: UUID) throws(PersistenceError) -> Migraine? { storage.first { $0.id == id } }
    public func count() throws(PersistenceError) -> Int { storage.count }
    public func insert(_ migraine: Migraine) throws(PersistenceError) {
        let sample = IntensitySample(timestamp: migraine.startDate, painLevel: migraine.painLevel, stressLevel: migraine.stressLevel, parentMigraine: migraine)
        migraine.intensitySamples = (migraine.intensitySamples ?? []) + [sample]
        storage.append(migraine)
        changeCenter.notify(.migraineLogged(migraine.id))
    }
    public func update(_ migraine: Migraine, configure: (Migraine) -> Void) throws(PersistenceError) {
        configure(migraine)
        changeCenter.notify(.migraineUpdated(migraine.id))
    }
    public func delete(_ migraine: Migraine) throws(PersistenceError) {
        storage.removeAll { $0.id == migraine.id }
        changeCenter.notify(.migraineDeleted(migraine.id))
    }
    public func deleteAll() throws(PersistenceError) {
        storage.removeAll()
        changeCenter.notify(.bulk)
    }
    @discardableResult
    public func addIntensitySample(to migraine: Migraine, timestamp: Date, painLevel: Int, stressLevel: Int, note: String?) throws(PersistenceError) -> IntensitySample {
        let sample = IntensitySample(timestamp: timestamp, painLevel: painLevel, stressLevel: stressLevel, note: note, parentMigraine: migraine)
        migraine.intensitySamples = (migraine.intensitySamples ?? []) + [sample]
        migraine.painLevel = painLevel
        migraine.stressLevel = stressLevel
        changeCenter.notify(.migraineUpdated(migraine.id))
        return sample
    }
    public func removeIntensitySample(_ sample: IntensitySample, from migraine: Migraine) throws(PersistenceError) {
        migraine.intensitySamples?.removeAll { $0.id == sample.id }
        changeCenter.notify(.migraineUpdated(migraine.id))
    }
}

@MainActor
public final class PreviewTagRepository: TagRepository {
    public var storage: [MigraineTag]
    public let changeCenter: MigraineChangeCenter

    public init(storage: [MigraineTag] = [], changeCenter: MigraineChangeCenter = MigraineChangeCenter()) {
        self.storage = storage
        self.changeCenter = changeCenter
    }

    public func tags() throws(PersistenceError) -> [MigraineTag] { storage.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) } }
    @discardableResult
    public func create(name: String, colorHex: String) throws(PersistenceError) -> MigraineTag {
        let tag = MigraineTag(name: name, colorHex: colorHex, sortIndex: (storage.map(\.sortIndex).max() ?? -1) + 1)
        storage.append(tag)
        changeCenter.notify(.tagsChanged)
        return tag
    }
    public func update(_ tag: MigraineTag, name: String?, colorHex: String?) throws(PersistenceError) {
        if let name { tag.name = name }
        if let colorHex { tag.colorHex = colorHex }
        changeCenter.notify(.tagsChanged)
    }
    public func delete(_ tag: MigraineTag) throws(PersistenceError) {
        storage.removeAll { $0.id == tag.id }
        changeCenter.notify(.tagsChanged)
    }
    public func move(fromOffsets source: IndexSet, toOffset destination: Int) throws(PersistenceError) {
        for (index, tag) in try tags().moving(fromOffsets: source, toOffset: destination).enumerated() {
            tag.sortIndex = index
        }
        changeCenter.notify(.tagsChanged)
    }
    public func setTags(_ tags: [MigraineTag], for migraine: Migraine) throws(PersistenceError) {
        migraine.tags = tags
        changeCenter.notify(.tagsChanged)
    }
}

@MainActor
public final class PreviewUserRepository: UserRepository {
    public var user: User?
    public let changeCenter: MigraineChangeCenter

    public init(user: User? = nil, changeCenter: MigraineChangeCenter = MigraineChangeCenter()) {
        self.user = user
        self.changeCenter = changeCenter
    }

    public func currentUser() throws(PersistenceError) -> User? { user }
    public func replace(with user: User) throws(PersistenceError) {
        self.user = user
        changeCenter.notify(.userChanged)
    }
    public func update(configure: (User) -> Void) throws(PersistenceError) {
        guard let user else { throw .notFound }
        configure(user)
        changeCenter.notify(.userChanged)
    }
    public func deleteUser() throws(PersistenceError) {
        user = nil
        changeCenter.notify(.userChanged)
    }
}

/// An intelligence stand-in that is "unavailable" (previews render the upgrade card).
@MainActor
public final class PreviewIntelligence: MigraineIntelligence {
    public var isAvailable: Bool
    public private(set) var conversation: [ChatMessage] = []
    public private(set) var isChatActive = false

    public init(isAvailable: Bool = false) {
        self.isAvailable = isAvailable
    }

    public func analyze(migraine: Migraine, user: User?) async throws -> String? { nil }
    public func explain(insight: Insight, user: User?) async throws -> QuickBitExplanation? {
        QuickBitExplanation(description: "A short explanation.", recommendation: "Try a small change.")
    }
    public func startChat(migraines: [Migraine], user: User?) async {
        conversation = [.assistant("Hi! What would you like to explore?")]
        isChatActive = true
    }
    public func send(message: String) async throws -> String {
        conversation.append(.user(message))
        let reply = "Echo: \(message)"
        conversation.append(.assistant(reply))
        return reply
    }
    public func resetChat() {
        conversation.removeAll()
        isChatActive = false
    }
}

// MARK: - Environment

@MainActor
public struct PreviewEnvironment {
    public let changeCenter = MigraineChangeCenter()
    public let migraineRepository: PreviewMigraineRepository
    public let tagRepository: PreviewTagRepository
    public let userRepository: PreviewUserRepository
    public let toastManager = ToastManager()
    public let migraineData: MigraineDataModel
    public let tagData: TagDataModel
    public let userData: UserDataModel
    public let insights: InsightModel
    public let weatherManager: WeatherManager
    public let notificationManager = NotificationManager()
    public let cloudSyncManager = CloudSyncManager()
    #if canImport(HealthKit) && !os(macOS)
    public let healthManager = HealthManager()
    #endif

    /// Builds the graph over in-memory stores, seeded with `migraines`.
    public init(migraines: [Migraine] = [Migraine.sample(), Migraine.sampleOngoing()], tags: [MigraineTag] = [], user: User? = User(name: "Nick")) {
        migraineRepository = PreviewMigraineRepository(storage: migraines, changeCenter: changeCenter)
        tagRepository = PreviewTagRepository(storage: tags, changeCenter: changeCenter)
        userRepository = PreviewUserRepository(user: user, changeCenter: changeCenter)
        let observe = ObserveMigraineChangesUseCase(center: changeCenter)
        let update = UpdateMigraineUseCase(repository: migraineRepository)
        let log = LogMigraineUseCase(repository: migraineRepository)

        migraineData = MigraineDataModel(
            loadMigraines: LoadMigrainesUseCase(repository: migraineRepository),
            findMigraine: FindMigraineUseCase(repository: migraineRepository),
            countMigraines: CountMigrainesUseCase(repository: migraineRepository),
            logMigraine: log,
            startMigraine: StartMigraineUseCase(repository: migraineRepository, log: log),
            updateMigraine: update,
            endOngoing: EndOngoingMigraineUseCase(repository: migraineRepository, update: update),
            deleteMigraine: DeleteMigraineUseCase(repository: migraineRepository),
            deleteAll: DeleteAllMigrainesUseCase(repository: migraineRepository),
            recordIntensitySample: RecordIntensitySampleUseCase(repository: migraineRepository),
            removeIntensitySample: RemoveIntensitySampleUseCase(repository: migraineRepository),
            observeChanges: observe,
            toastManager: toastManager
        )
        tagData = TagDataModel(
            loadTags: LoadTagsUseCase(repository: tagRepository),
            createTag: CreateTagUseCase(repository: tagRepository),
            updateTag: UpdateTagUseCase(repository: tagRepository),
            deleteTag: DeleteTagUseCase(repository: tagRepository),
            reorderTags: ReorderTagsUseCase(repository: tagRepository),
            assignTags: AssignTagsUseCase(repository: tagRepository),
            observeChanges: observe,
            toastManager: toastManager
        )
        userData = UserDataModel(
            loadUser: LoadUserUseCase(repository: userRepository),
            saveUser: SaveUserUseCase(repository: userRepository),
            updateUser: UpdateUserUseCase(repository: userRepository),
            deleteUser: DeleteUserUseCase(repository: userRepository),
            observeChanges: observe,
            toastManager: toastManager
        )
        insights = InsightModel(
            loadMigraines: LoadMigrainesUseCase(repository: migraineRepository),
            findMigraine: FindMigraineUseCase(repository: migraineRepository),
            loadUser: LoadUserUseCase(repository: userRepository),
            updateMigraine: update,
            observeChanges: observe,
            intelligence: PreviewIntelligence()
        )
        weatherManager = WeatherManager(locationManager: LocationManager())
    }
}

extension View {
    /// Injects a complete preview dependency graph.
    @MainActor
    public func previewEnvironment(_ environment: PreviewEnvironment? = nil) -> some View {
        let env = environment ?? PreviewEnvironment()
        let base = self
            .environment(env.migraineData)
            .environment(env.tagData)
            .environment(env.userData)
            .environment(env.insights)
            .environment(env.weatherManager)
            .environment(env.notificationManager)
            .environment(env.cloudSyncManager)
            .environment(env.toastManager)
        #if canImport(HealthKit) && !os(macOS)
        return base.environment(env.healthManager)
        #else
        return base
        #endif
    }
}
#endif
