//
//  ClinicalReportSetupView.swift
//  MygraFeatureSettings
//
//  Configures the clinical PDF: 1, 3, or 6 months; which patient details to print (all
//  optional); and the MIDAS and HIT-6 questionnaires, whose latest answers are saved
//  and printed with their score and band. The PDF itself is a Mygra Plus feature.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct ClinicalReportSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.reportWindowMonths) private var months = 3
    @AppStorage(AppStorageKeys.reportIncludeName) private var includeName = true
    @AppStorage(AppStorageKeys.reportIncludeBirthday) private var includeBirthday = false
    @AppStorage(AppStorageKeys.reportIncludeHealthProfile) private var includeHealthProfile = true

    @State private var assessment: ClinicalAssessment
    private let store: ClinicalAssessmentStore

    let onCreate: (ClinicalReportOptions, ClinicalAssessment) -> Void

    init(store: ClinicalAssessmentStore = ClinicalAssessmentStore(defaults: UserDefaults.standard), onCreate: @escaping (ClinicalReportOptions, ClinicalAssessment) -> Void) {
        self.store = store
        self.onCreate = onCreate
        _assessment = State(initialValue: store.load())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period", selection: $months) {
                        ForEach(ClinicalReportOptions.allowedMonths, id: \.self) { value in
                            Text(value == 1 ? LocalizedStringKey("1 month") : LocalizedStringKey("\(value) months")).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Report Period")
                }

                Section {
                    Toggle("Name", isOn: $includeName)
                    Toggle("Birthday", isOn: $includeBirthday)
                    Toggle("Health profile (sex, height, weight, sleep, conditions)", isOn: $includeHealthProfile)
                } header: {
                    Text("Patient Details")
                } footer: {
                    Text("Everything here is optional. Leave details off to share an anonymous report.")
                }

                Section {
                    NavigationLink {
                        MIDASFormView(assessment: $assessment, store: store)
                    } label: {
                        scoreRow(title: "MIDAS", detail: assessment.midasScore.map { score in
                            "\(score) · \(MIDAS.grade(forScore: score).label)"
                        })
                    }
                    NavigationLink {
                        HIT6FormView(assessment: $assessment, store: store)
                    } label: {
                        scoreRow(title: "HIT-6", detail: assessment.hit6Score.map { score in
                            "\(score) · \(HIT6.band(forScore: score).label)"
                        })
                    }
                } header: {
                    Text("Questionnaires")
                } footer: {
                    Text("MIDAS measures lost days over 3 months; HIT-6 measures the impact of headaches over 4 weeks. Both are screening aids, not a diagnosis. Completed answers are printed in the report.")
                }
            }
            .navigationTitle("Clinical Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create PDF") {
                        onCreate(
                            ClinicalReportOptions(months: months, includeName: includeName, includeBirthday: includeBirthday, includeHealthProfile: includeHealthProfile),
                            assessment
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("createClinicalReport")
                }
            }
        }
    }

    private func scoreRow(title: LocalizedStringKey, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail ?? String(localized: "Not completed"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - MIDAS

private struct MIDASFormView: View {
    @Binding var assessment: ClinicalAssessment
    let store: ClinicalAssessmentStore
    @State private var answers: [Int]

    init(assessment: Binding<ClinicalAssessment>, store: ClinicalAssessmentStore) {
        _assessment = assessment
        self.store = store
        _answers = State(initialValue: assessment.wrappedValue.midasAnswers ?? Array(repeating: 0, count: MIDAS.questionCount))
    }

    var body: some View {
        Form {
            ForEach(Array(MIDAS.questions.enumerated()), id: \.offset) { index, question in
                Section {
                    Stepper(value: $answers[index], in: 0...MIDAS.maxDaysPerQuestion) {
                        Text(answers[index] == 1 ? LocalizedStringKey("\(answers[index]) day") : LocalizedStringKey("\(answers[index]) days"))
                    }
                } header: {
                    Text(question).textCase(nil).font(.subheadline).foregroundStyle(.primary)
                }
            }
            if let score = MIDAS.score(answers) {
                Section("Result") {
                    Text("Score \(score): \(MIDAS.grade(forScore: score).label)")
                }
            }
        }
        .navigationTitle("MIDAS")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { save() }
    }

    private func save() {
        assessment.midasAnswers = answers
        assessment.midasDate = Date()
        store.save(assessment)
    }
}

// MARK: - HIT-6

private struct HIT6FormView: View {
    @Binding var assessment: ClinicalAssessment
    let store: ClinicalAssessmentStore
    @State private var answers: [HIT6.Answer]

    init(assessment: Binding<ClinicalAssessment>, store: ClinicalAssessmentStore) {
        _assessment = assessment
        self.store = store
        _answers = State(initialValue: assessment.wrappedValue.hit6Answers ?? Array(repeating: .never, count: HIT6.questionCount))
    }

    var body: some View {
        Form {
            ForEach(Array(HIT6.questions.enumerated()), id: \.offset) { index, question in
                Section {
                    Picker("Answer", selection: $answers[index]) {
                        ForEach(HIT6.Answer.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(question).textCase(nil).font(.subheadline).foregroundStyle(.primary)
                }
            }
            if let score = HIT6.score(answers) {
                Section("Result") {
                    Text("Score \(score) of 78: \(HIT6.band(forScore: score).label)")
                }
            }
        }
        .navigationTitle("HIT-6")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { save() }
    }

    private func save() {
        assessment.hit6Answers = answers
        assessment.hit6Date = Date()
        store.save(assessment)
    }
}
#endif
