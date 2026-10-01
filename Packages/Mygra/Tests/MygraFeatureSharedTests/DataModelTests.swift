//
//  DataModelTests.swift
//  MygraFeatureSharedTests
//
//  Behavior tests for the shared view-facing models over the in-memory preview
//  repositories: verb routing, change-stream refreshes, error toasting (never silent),
//  the review milestone, and the insight model's reactions.
//

import Foundation
import Testing
import MygraCore
import MygraDesignSystem
@testable import MygraFeatureShared

@MainActor
private final class FakeKeyValueStore: KeyValueStoring {
    var storage: [String: Any] = [:]
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

@MainActor
private final class FakeReviewRequester: ReviewRequesting {
    private(set) var requestCount = 0
    func requestReview() { requestCount += 1 }
}

/// A `LogMigraine` that fails on demand.
@MainActor
private struct FailingLog: LogMigraine {
    func callAsFunction(_ migraine: Migraine) throws(PersistenceError) { throw .saveFailed("disk full") }
}

@MainActor
private func makeMigraineData(
    repository: PreviewMigraineRepository,
    toastManager: ToastManager = ToastManager(),
    reviewRequester: (any ReviewRequesting)? = nil,
    defaults: any KeyValueStoring = FakeKeyValueStore(),
    log: (any LogMigraine)? = nil
) -> MigraineDataModel {
    let update = UpdateMigraineUseCase(repository: repository)
    let logUseCase: any LogMigraine = log ?? LogMigraineUseCase(repository: repository)
    return MigraineDataModel(
        loadMigraines: LoadMigrainesUseCase(repository: repository),
        findMigraine: FindMigraineUseCase(repository: repository),
        countMigraines: CountMigrainesUseCase(repository: repository),
        logMigraine: logUseCase,
        startMigraine: StartMigraineUseCase(repository: repository, log: logUseCase),
        updateMigraine: update,
        endOngoing: EndOngoingMigraineUseCase(repository: repository, update: update),
        deleteMigraine: DeleteMigraineUseCase(repository: repository),
        deleteAll: DeleteAllMigrainesUseCase(repository: repository),
        recordIntensitySample: RecordIntensitySampleUseCase(repository: repository),
        removeIntensitySample: RemoveIntensitySampleUseCase(repository: repository),
        observeChanges: ObserveMigraineChangesUseCase(center: repository.changeCenter),
        reviewRequester: reviewRequester,
        defaults: defaults,
        toastManager: toastManager
    )
}

@Suite("MigraineDataModel")
@MainActor
struct MigraineDataModelTests {

    @Test("verbs route through their use-cases and the cache refreshes")
    func verbsRoute() async {
        let repository = PreviewMigraineRepository()
        let model = makeMigraineData(repository: repository)
        #expect(model.migraines.isEmpty)

        let migraine = Migraine(startDate: Date(), painLevel: 6, stressLevel: 2)
        #expect(model.log(migraine))
        #expect(model.migraines.count == 1)
        #expect(model.ongoingMigraine?.id == migraine.id)

        model.addIntensitySample(to: migraine, painLevel: 9, stressLevel: 4)
        #expect(migraine.painLevel == 9)

        #expect(model.endOngoing())
        #expect(model.ongoingMigraine == nil)

        model.togglePinned(migraine)
        #expect(migraine.isPinned)

        model.delete(migraine)
        #expect(model.migraines.isEmpty)
    }

    @Test("start refuses a second ongoing migraine")
    func startRefusesDuplicates() {
        let model = makeMigraineData(repository: PreviewMigraineRepository())
        #expect(model.start(painLevel: 5, stressLevel: 5) != nil)
        #expect(model.start(painLevel: 5, stressLevel: 5) == nil)
    }

    @Test("the filter drives visibleMigraines")
    func filterApplies() {
        let repository = PreviewMigraineRepository(storage: [
            Migraine(startDate: Date(), endDate: Date(), painLevel: 8, stressLevel: 5),
            Migraine(startDate: Date().addingTimeInterval(-3600), endDate: Date(), painLevel: 2, stressLevel: 1),
        ])
        let model = makeMigraineData(repository: repository)
        model.filter.minPainLevel = 5
        #expect(model.visibleMigraines.count == 1)
        #expect(model.visibleMigraines.first?.painLevel == 8)
    }

    @Test("failures surface as error toasts, never silently")
    func failuresToast() {
        let toastManager = ToastManager()
        let model = makeMigraineData(repository: PreviewMigraineRepository(), toastManager: toastManager, log: FailingLog())
        #expect(model.log(Migraine(startDate: Date(), painLevel: 1, stressLevel: 1)) == false)
        #expect(toastManager.currentToast?.style == .error)
    }

    @Test("the review prompt fires once, on the fifth migraine")
    func reviewMilestone() {
        let requester = FakeReviewRequester()
        let defaults = FakeKeyValueStore()
        let model = makeMigraineData(repository: PreviewMigraineRepository(), reviewRequester: requester, defaults: defaults)
        for index in 1...6 {
            model.log(Migraine(startDate: Date().addingTimeInterval(Double(-index)), endDate: Date(), painLevel: 3, stressLevel: 3))
        }
        #expect(requester.requestCount == 1)
        #expect(defaults.bool(forKey: AppStorageKeys.hasPromptedForFifthReview))
    }

    @Test("change-stream events from elsewhere refresh the cache")
    func externalChangesRefresh() async throws {
        let repository = PreviewMigraineRepository()
        let model = makeMigraineData(repository: repository)
        let before = model.changeStamp
        let migraine = Migraine(startDate: Date(), painLevel: 4, stressLevel: 4)
        // The observer subscribes asynchronously; keep notifying until the event lands.
        repository.storage = [migraine]
        for _ in 0..<100 where model.migraines.isEmpty {
            repository.changeCenter.notify(.migraineLogged(migraine.id))
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.migraines.count == 1)
        #expect(model.changeStamp > before)
    }
}

@Suite("TagDataModel & UserDataModel")
@MainActor
struct TagAndUserDataModelTests {
    @Test func tagVerbsRoute() {
        let repository = PreviewTagRepository()
        let model = TagDataModel(
            loadTags: LoadTagsUseCase(repository: repository),
            createTag: CreateTagUseCase(repository: repository),
            updateTag: UpdateTagUseCase(repository: repository),
            deleteTag: DeleteTagUseCase(repository: repository),
            reorderTags: ReorderTagsUseCase(repository: repository),
            assignTags: AssignTagsUseCase(repository: repository),
            observeChanges: ObserveMigraineChangesUseCase(center: repository.changeCenter),
            toastManager: ToastManager()
        )
        let a = model.create(name: "A")
        model.create(name: "B")
        model.refresh()
        #expect(model.tags.map(\.name) == ["A", "B"])

        model.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        model.refresh()
        #expect(model.tags.map(\.name) == ["B", "A"])

        let migraine = Migraine(startDate: Date(), painLevel: 1, stressLevel: 1)
        model.setTags([a!], for: migraine)
        #expect(migraine.tags?.count == 1)

        model.update(a!, name: "Alpha")
        #expect(a?.name == "Alpha")
        model.delete(a!)
        model.refresh()
        #expect(model.tags.map(\.name) == ["B"])
    }

    @Test func userVerbsRouteAndMissingUserToasts() {
        let repository = PreviewUserRepository()
        let toastManager = ToastManager()
        let model = UserDataModel(
            loadUser: LoadUserUseCase(repository: repository),
            saveUser: SaveUserUseCase(repository: repository),
            updateUser: UpdateUserUseCase(repository: repository),
            deleteUser: DeleteUserUseCase(repository: repository),
            observeChanges: ObserveMigraineChangesUseCase(center: repository.changeCenter),
            toastManager: toastManager
        )
        #expect(model.currentUser == nil)
        model.update { $0.name = "x" }
        #expect(toastManager.currentToast?.style == .error)

        model.save(User(name: "Nick"))
        model.refresh()
        #expect(model.currentUser?.name == "Nick")

        let edited = User(name: "Nicholas", averageSleepHours: 6)
        model.apply(edited)
        #expect(model.currentUser?.name == "Nicholas")
        #expect(model.currentUser?.averageSleepHours == 6)
    }
}

@Suite("InsightModel")
@MainActor
struct InsightModelTests {
    @MainActor
    private final class ScriptedIntelligence: MigraineIntelligence {
        var isAvailable = true
        private(set) var conversation: [ChatMessage] = []
        private(set) var isChatActive = false
        var analysis: String? = "Likely stress."
        private(set) var analyzed: [UUID] = []
        func analyze(migraine: Migraine, user: User?) async throws -> String? {
            analyzed.append(migraine.id)
            return analysis
        }
        func explain(insight: Insight, user: User?) async throws -> QuickBitExplanation? {
            QuickBitExplanation(description: "d", recommendation: "r")
        }
        func startChat(migraines: [Migraine], user: User?) async {
            conversation = [.assistant("hi")]
            isChatActive = true
        }
        func send(message: String) async throws -> String {
            conversation.append(.user(message))
            return "reply"
        }
        func resetChat() {
            conversation = []
            isChatActive = false
        }
    }

    private func makeModel(repository: PreviewMigraineRepository, intelligence: ScriptedIntelligence) -> InsightModel {
        InsightModel(
            loadMigraines: LoadMigrainesUseCase(repository: repository),
            findMigraine: FindMigraineUseCase(repository: repository),
            loadUser: LoadUserUseCase(repository: PreviewUserRepository()),
            updateMigraine: UpdateMigraineUseCase(repository: repository),
            observeChanges: ObserveMigraineChangesUseCase(center: repository.changeCenter),
            intelligence: intelligence
        )
    }

    @Test func refreshGeneratesRuleInsights() {
        let now = Date()
        let repository = PreviewMigraineRepository(storage: (0..<4).map { i in
            Migraine(startDate: now.addingTimeInterval(Double(-i) * 86_400), painLevel: 5, stressLevel: 5, triggers: [.stress])
        })
        let model = makeModel(repository: repository, intelligence: ScriptedIntelligence())
        model.refresh()
        #expect(model.insights.contains { $0.category == .triggers })
        #expect(model.lastRefreshed != nil)
    }

    @Test func loggedMigraineIsAnalyzedAndStored() async throws {
        let repository = PreviewMigraineRepository()
        let intelligence = ScriptedIntelligence()
        let model = makeModel(repository: repository, intelligence: intelligence)
        let migraine = Migraine(startDate: Date(), painLevel: 7, stressLevel: 7)

        repository.storage = [migraine]
        for _ in 0..<100 where intelligence.analyzed.isEmpty {
            repository.changeCenter.notify(.migraineLogged(migraine.id))
            try? await Task.sleep(for: .milliseconds(10))
        }
        for _ in 0..<50 where migraine.insight == nil {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(migraine.insight == "Likely stress.")
        #expect(model.generatedGuidance[migraine.id] == "Likely stress.")
        #expect(model.insights.first?.category == .generative)
    }

    @Test func explanationsAreCachedPerQuickBit() async {
        let model = makeModel(repository: PreviewMigraineRepository(), intelligence: ScriptedIntelligence())
        let insight = Insight(category: .foods, title: "t", message: "m", priority: .low)
        let first = await model.explanation(for: insight)
        #expect(first?.description == "d")
        #expect(model.quickBitExplanations.count == 1)
        _ = await model.explanation(for: insight)
        #expect(model.quickBitExplanations.count == 1)
    }

    @Test func chatRoutesAndUnavailabilityIsReported() async {
        let intelligence = ScriptedIntelligence()
        let model = makeModel(repository: PreviewMigraineRepository(), intelligence: intelligence)
        await model.startChat()
        #expect(model.isChatActive)
        #expect(await model.send("hello") == "reply")
        #expect(model.conversation.count == 2)
        model.resetChat()
        #expect(!model.isChatActive)

        intelligence.isAvailable = false
        _ = await model.send("again")
        #expect(model.errors.contains(.unavailable))
        model.clearErrors()
        #expect(model.errors.isEmpty)
    }
}
