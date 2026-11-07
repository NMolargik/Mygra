//
//  MedicationOveruseNotifierTests.swift
//  MygraServicesTests
//

import Foundation
import Testing
import MygraCore
@testable import MygraServices

@MainActor
private final class FakeTimeSensitiveNotifier: LocalNotifying {
    var authorized = true
    private(set) var plain: [String] = []
    private(set) var timeSensitive: [(title: String, body: String, identifier: String)] = []
    var isAuthorized: Bool { get async { authorized } }
    func send(title: String, body: String, identifier: String) async throws { plain.append(identifier) }
    func sendTimeSensitive(title: String, body: String, identifier: String) async throws {
        timeSensitive.append((title, body, identifier))
    }
}

private final class Store: KeyValueStoring, @unchecked Sendable {
    var storage: [String: Any] = [:]
    func bool(forKey k: String) -> Bool { storage[k] as? Bool ?? false }
    func double(forKey k: String) -> Double { storage[k] as? Double ?? 0 }
    func integer(forKey k: String) -> Int { storage[k] as? Int ?? 0 }
    func string(forKey k: String) -> String? { storage[k] as? String }
    func data(forKey k: String) -> Data? { storage[k] as? Data }
    func object(forKey k: String) -> Any? { storage[k] }
    func set(_ v: Any?, forKey k: String) { storage[k] = v }
    func removeObject(forKey k: String) { storage.removeValue(forKey: k) }
}

@Suite("MedicationOveruseNotifier")
@MainActor
struct MedicationOveruseNotifierTests {
    private let now = Date(timeIntervalSince1970: 1_794_052_800)

    private func migraine(triptanDays: Int) -> Migraine {
        let m = Migraine(startDate: now.addingTimeInterval(-3600), painLevel: 6, stressLevel: 3)
        m.medications = (0..<triptanDays).map {
            MedicationDose(name: "Sumatriptan", medicationClass: .triptan, takenAt: now.addingTimeInterval(-Double($0) * 86_400), migraine: m)
        }
        return m
    }

    @Test func sendsTimeSensitiveOncePerLevel() async {
        let fake = FakeTimeSensitiveNotifier()
        let sut = MedicationOveruseNotifier(notifications: fake, defaults: Store(), now: { now })

        #expect(await sut.checkAndNotify(migraines: [migraine(triptanDays: 7)]).isEmpty)
        #expect((await sut.checkAndNotify(migraines: [migraine(triptanDays: 8)])).count == 1)
        #expect((await sut.checkAndNotify(migraines: [migraine(triptanDays: 9)])).isEmpty)
        let threshold = await sut.checkAndNotify(migraines: [migraine(triptanDays: 10)])
        #expect(threshold.first?.status == .threshold)

        #expect(fake.timeSensitive.count == 2)
        #expect(fake.plain.isEmpty)
        #expect(fake.timeSensitive.last?.body.contains("not medical advice") == true)
    }

    @Test func skipsDeliveryWithoutAuthorization() async {
        let fake = FakeTimeSensitiveNotifier()
        fake.authorized = false
        let sut = MedicationOveruseNotifier(notifications: fake, defaults: Store(), now: { now })
        #expect(await sut.checkAndNotify(migraines: [migraine(triptanDays: 10)]).isEmpty)
        #expect(fake.timeSensitive.isEmpty)
    }
}
