import Foundation
import Testing
import HealthKit
@testable import Mygra

@Suite("HealthManager basic tests")
struct HealthManagerTests {

    @Test
    func authorizationFlagReflectsPerTypeStatuses() async throws {
        let fake = FakeStore()
        // Simulate read types authorized by default
        fake.authStatuses = [
            // Use identifiers that HealthManager will request; we can't access private properties, so simulate a mix
            HKQuantityTypeIdentifier.dietaryWater.rawValue: .sharingAuthorized,
            HKQuantityTypeIdentifier.stepCount.rawValue: .sharingAuthorized
        ]

        let manager = await HealthManager(store: fake)
        await manager.requestAuthorization()
        // isAuthorized depends on readOK; since not all types are set, it may be false
        // For the purpose of this test, mark all as authorized
        for id in [
            HKQuantityTypeIdentifier.dietaryWater.rawValue,
            HKQuantityTypeIdentifier.dietaryCaffeine.rawValue,
            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue,
            HKQuantityTypeIdentifier.stepCount.rawValue,
            HKQuantityTypeIdentifier.restingHeartRate.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue,
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            HKQuantityTypeIdentifier.bloodGlucose.rawValue,
            HKQuantityTypeIdentifier.oxygenSaturation.rawValue,
            HKCategoryTypeIdentifier.headache.rawValue
        ] {
            fake.authStatuses[id] = .sharingAuthorized
        }
        await manager.requestAuthorization()
        let (authorized1, error1) = await MainActor.run { (manager.isAuthorized, manager.lastError) }
        #expect(authorized1 == true)
        #expect(error1 == nil)
    }

    @Test
    func saveIntakeWritesSamples() async throws {
        let fake = FakeStore()
        // Authorize writes
        fake.authStatuses = [
            HKQuantityTypeIdentifier.dietaryWater.rawValue: .sharingAuthorized,
            HKQuantityTypeIdentifier.dietaryCaffeine.rawValue: .sharingAuthorized,
            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: .sharingAuthorized,
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: .sharingAuthorized
        ]
        let manager = await HealthManager(store: fake)

        try await manager.saveWater(liters: 0.25)
        try await manager.saveCaffeine(mg: 80)
        try await manager.saveEnergy(kcal: 500)
        let end = Date(); let start = end.addingTimeInterval(-3600)
        try await manager.saveSleep(from: start, to: end)

        #expect(fake.saved.count == 4)
    }
}
