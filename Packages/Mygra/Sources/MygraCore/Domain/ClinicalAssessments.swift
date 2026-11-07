//
//  ClinicalAssessments.swift
//  MygraCore
//
//  Scoring for the two questionnaires clinics ask for: MIDAS (disability, days lost over
//  three months) and HIT-6 (headache impact). Pure scoring, banding, and storage of the
//  latest answers. The questions are paraphrased in the app's own words; they
//  are screening aids and not a diagnosis.
//

import Foundation

// MARK: - MIDAS

nonisolated public enum MIDAS {
    public static let questionCount = 5

    public static var questions: [String] {
        [
            String(localized: "On how many days in the last 3 months did you miss work or school because of your headaches?"),
            String(localized: "On how many days in the last 3 months was your productivity at work or school cut by half or more because of your headaches? (Don't count days you already counted above.)"),
            String(localized: "On how many days in the last 3 months did you not do household work because of your headaches?"),
            String(localized: "On how many days in the last 3 months was your productivity in household work cut by half or more because of your headaches? (Don't count days you already counted above.)"),
            String(localized: "On how many days in the last 3 months did you miss family, social, or leisure activities because of your headaches?"),
        ]
    }

    /// Each answer is a count of days, 0...92 (about three months).
    public static let maxDaysPerQuestion = 92

    public enum Grade: Int, Codable, Sendable {
        case I = 1, II, III, IV

        public var disability: String {
            switch self {
            case .I: String(localized: "little or no disability")
            case .II: String(localized: "mild disability")
            case .III: String(localized: "moderate disability")
            case .IV: String(localized: "severe disability")
            }
        }

        public var label: String {
            let numeral = switch self { case .I: "I"; case .II: "II"; case .III: "III"; case .IV: "IV" }
            return String(localized: "Grade \(numeral): \(disability)")
        }
    }

    /// Total days lost; nil unless all five answers are present.
    public static func score(_ answers: [Int]) -> Int? {
        guard answers.count == questionCount else { return nil }
        return answers.reduce(0) { $0 + min(max($1, 0), maxDaysPerQuestion) }
    }

    public static func grade(forScore score: Int) -> Grade {
        switch score {
        case ..<6: .I
        case 6...10: .II
        case 11...20: .III
        default: .IV
        }
    }
}

// MARK: - HIT-6

nonisolated public enum HIT6 {
    public static let questionCount = 6

    public static var questions: [String] {
        [
            String(localized: "When you have headaches, how often is the pain severe?"),
            String(localized: "How often do headaches limit your ability to do usual daily activities, including household work, work, school, or social activities?"),
            String(localized: "When you have a headache, how often do you wish you could lie down?"),
            String(localized: "In the last 4 weeks, how often have you felt too tired to do work or daily activities because of your headaches?"),
            String(localized: "In the last 4 weeks, how often have you felt fed up or irritated because of your headaches?"),
            String(localized: "In the last 4 weeks, how often did headaches limit your ability to concentrate on work or daily activities?"),
        ]
    }

    public enum Answer: Int, CaseIterable, Codable, Sendable, Identifiable {
        case never = 6
        case rarely = 8
        case sometimes = 10
        case veryOften = 11
        case always = 13

        public var id: Int { rawValue }

        public var label: String {
            switch self {
            case .never: String(localized: "Never")
            case .rarely: String(localized: "Rarely")
            case .sometimes: String(localized: "Sometimes")
            case .veryOften: String(localized: "Very often")
            case .always: String(localized: "Always")
            }
        }
    }

    public enum Band: Sendable {
        case little, some, substantial, severe

        public var label: String {
            switch self {
            case .little: String(localized: "Little or no impact")
            case .some: String(localized: "Some impact")
            case .substantial: String(localized: "Substantial impact")
            case .severe: String(localized: "Severe impact")
            }
        }
    }

    /// 36...78; nil unless all six answers are present.
    public static func score(_ answers: [Answer]) -> Int? {
        guard answers.count == questionCount else { return nil }
        return answers.reduce(0) { $0 + $1.rawValue }
    }

    public static func band(forScore score: Int) -> Band {
        switch score {
        case ..<50: .little
        case 50...55: .some
        case 56...59: .substantial
        default: .severe
        }
    }
}

// MARK: - Stored answers

/// The latest questionnaire answers, kept so the report can print the score and date.
nonisolated public struct ClinicalAssessment: Codable, Equatable, Sendable {
    public var midasDate: Date?
    public var midasAnswers: [Int]?
    public var hit6Date: Date?
    public var hit6Answers: [HIT6.Answer]?

    public init(midasDate: Date? = nil, midasAnswers: [Int]? = nil, hit6Date: Date? = nil, hit6Answers: [HIT6.Answer]? = nil) {
        self.midasDate = midasDate
        self.midasAnswers = midasAnswers
        self.hit6Date = hit6Date
        self.hit6Answers = hit6Answers
    }

    public var midasScore: Int? { midasAnswers.flatMap(MIDAS.score) }
    public var hit6Score: Int? { hit6Answers.flatMap(HIT6.score) }
}

nonisolated public struct ClinicalAssessmentStore {
    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring) { self.defaults = defaults }

    public func load() -> ClinicalAssessment {
        guard let data = defaults.data(forKey: AppStorageKeys.clinicalAssessment),
              let decoded = try? JSONDecoder().decode(ClinicalAssessment.self, from: data) else { return ClinicalAssessment() }
        return decoded
    }

    public func save(_ assessment: ClinicalAssessment) {
        defaults.set(try? JSONEncoder().encode(assessment), forKey: AppStorageKeys.clinicalAssessment)
    }
}
