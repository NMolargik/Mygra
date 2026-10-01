//
//  ModifyMigraineSheetView.swift
//  MygraFeatureMigraines
//
//  Edits a completed migraine's timing, levels, triggers, and staged intake.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

/// The edits the modify sheet hands back.
struct MigraineEdits: Equatable {
    var startDate: Date
    var endDate: Date?
    var painLevel: Int
    var stressLevel: Int
    var triggers: Set<MigraineTrigger>
    var additions: IntakeAdditions

    /// Validates the timing. Returns a user-facing message when invalid.
    static func validationMessage(startDate: Date, endDate: Date?, now: Date = Date()) -> String? {
        guard startDate <= now else { return String(localized: "Start time cannot be in the future.") }
        if let endDate {
            if endDate < startDate { return String(localized: "End time must be after the start time.") }
            if endDate > now { return String(localized: "End time cannot be in the future.") }
        }
        return nil
    }
}

struct ModifyMigraineSheetView: View {
    let migraine: Migraine
    let onCancel: () -> Void
    let onSave: (MigraineEdits) -> Void

    @State private var editStartDate: Date
    @State private var editEndDate: Date
    @State private var editIsOngoing: Bool
    @State private var editPainLevel: Int
    @State private var editStressLevel: Int
    @State private var selectedTriggers: Set<MigraineTrigger>
    @State private var modifyError: String?
    @State private var additions = IntakeAdditions()
    @State private var isEditingIntake = false

    init(migraine: Migraine, onCancel: @escaping () -> Void, onSave: @escaping (MigraineEdits) -> Void) {
        self.migraine = migraine
        self.onCancel = onCancel
        self.onSave = onSave
        _editStartDate = State(initialValue: migraine.startDate)
        _editEndDate = State(initialValue: migraine.endDate ?? Date())
        _editIsOngoing = State(initialValue: migraine.endDate == nil)
        _editPainLevel = State(initialValue: migraine.painLevel)
        _editStressLevel = State(initialValue: migraine.stressLevel)
        _selectedTriggers = State(initialValue: Set(migraine.triggers))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    DurationSection(startTitle: "Start", startDate: $editStartDate, isOngoing: $editIsOngoing, endDate: $editEndDate)
                    if let modifyError {
                        Text(modifyError).font(.footnote).foregroundStyle(.red)
                    }
                }

                Section("Intake") {
                    if let health = migraine.health {
                        IntakeSection(
                            baseHealth: health,
                            isEditing: $isEditingIntake,
                            additions: $additions,
                            onConfirmAdd: {
                                Haptics.success()
                                withAnimation { isEditingIntake = false }
                            },
                            onCancel: { additions = .none }
                        )
                    } else {
                        Text("No health data was captured with this migraine.").foregroundStyle(.secondary)
                    }
                }

                Section("Experience") {
                    LevelSlider.pain(level: $editPainLevel)
                    LevelSlider.stress(level: $editStressLevel)
                }

                Section("Triggers") {
                    TriggerPickerSection(selection: $selectedTriggers, tint: .red)
                    if selectedTriggers.isEmpty {
                        Text("No triggers selected").foregroundStyle(.secondary)
                    } else {
                        Text("\(selectedTriggers.count) selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Modify Migraine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.lightImpact()
                        onCancel()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.lightImpact()
                        validateAndSave()
                    }
                    .tint(.mygraBlue)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private func validateAndSave() {
        let endDate: Date? = editIsOngoing ? nil : editEndDate
        if let message = MigraineEdits.validationMessage(startDate: editStartDate, endDate: endDate) {
            modifyError = message
            Haptics.error()
            return
        }
        modifyError = nil
        onSave(MigraineEdits(
            startDate: editStartDate,
            endDate: endDate,
            painLevel: editPainLevel,
            stressLevel: editStressLevel,
            triggers: selectedTriggers,
            additions: additions
        ))
    }
}

#if DEBUG
#Preview {
    ModifyMigraineSheetView(migraine: Migraine.sample(), onCancel: {}, onSave: { _ in })
}
#endif
#endif
