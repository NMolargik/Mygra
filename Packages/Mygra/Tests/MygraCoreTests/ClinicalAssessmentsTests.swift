//
//  ClinicalAssessmentsTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
@testable import MygraCore

@Suite("Clinical assessments")
struct ClinicalAssessmentsTests {

    @Test func midasSumsFiveAnswers() {
        #expect(MIDAS.score([1, 2, 3, 4, 5]) == 15)
        #expect(MIDAS.score([1, 2, 3]) == nil)
        #expect(MIDAS.score([0, 0, 0, 0, 0]) == 0)
        // Out-of-range input is clamped, never traps.
        #expect(MIDAS.score([-5, 500, 0, 0, 0]) == MIDAS.maxDaysPerQuestion)
    }

    @Test(arguments: [(0, MIDAS.Grade.I), (5, .I), (6, .II), (10, .II), (11, .III), (20, .III), (21, .IV), (90, .IV)])
    func midasGrades(score: Int, grade: MIDAS.Grade) {
        #expect(MIDAS.grade(forScore: score) == grade)
    }

    @Test func hit6ScoresAndBounds() {
        #expect(HIT6.score(Array(repeating: .never, count: 6)) == 36)
        #expect(HIT6.score(Array(repeating: .always, count: 6)) == 78)
        #expect(HIT6.score([.never, .rarely, .sometimes, .veryOften, .always, .never]) == 54)
        #expect(HIT6.score([.never]) == nil)
    }

    @Test(arguments: [(36, HIT6.Band.little), (49, .little), (50, .some), (55, .some), (56, .substantial), (59, .substantial), (60, .severe), (78, .severe)])
    func hit6Bands(score: Int, band: HIT6.Band) {
        #expect(HIT6.band(forScore: score) == band)
    }

    @Test func questionCountsMatchScoring() {
        #expect(MIDAS.questions.count == MIDAS.questionCount)
        #expect(HIT6.questions.count == HIT6.questionCount)
    }

    @Test func storeRoundTripsLatestAnswers() {
        let store = ClinicalAssessmentStore(defaults: FakeKeyValueStore())
        #expect(store.load() == ClinicalAssessment())
        let saved = ClinicalAssessment(
            midasDate: Date(timeIntervalSince1970: 100), midasAnswers: [1, 1, 1, 1, 1],
            hit6Date: Date(timeIntervalSince1970: 200), hit6Answers: Array(repeating: .sometimes, count: 6)
        )
        store.save(saved)
        let loaded = store.load()
        #expect(loaded == saved)
        #expect(loaded.midasScore == 5)
        #expect(loaded.hit6Score == 60)
    }
}
