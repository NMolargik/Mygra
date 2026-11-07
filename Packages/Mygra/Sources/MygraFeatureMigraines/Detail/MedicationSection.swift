//
//  MedicationSection.swift
//  MygraFeatureMigraines
//
//  Doses taken for an attack, plus the quick-add sheet: tap a common medication or type
//  one, pick its class and dose, and set when it was taken. Logging is free.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct MedicationSectionView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    let migraine: Migraine
    let onAdd: () -> Void

    var body: some View {
        InfoDetailView(title: String(localized: "Medication")) {
            VStack(alignment: .leading, spacing: Brand.Space.sm) {
                ForEach(migraine.sortedMedications) { dose in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dose.summary).font(.subheadline.weight(.semibold))
                            Text("\(dose.medicationClass.displayName) · \(DateFormatting.time(dose.takenAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Haptics.lightImpact()
                            migraineData.removeMedication(dose, from: migraine)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Remove \(dose.name)"))
                    }
                }
                Button {
                    Haptics.lightImpact()
                    onAdd()
                } label: {
                    Label("Add Medication", systemImage: "pills.fill")
                }
                .glassActionButton(tint: .mygraPurple)
                .accessibilityIdentifier("addMedicationButton")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MedicationQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    let migraine: Migraine
    let onSave: (_ name: String, _ medicationClass: MedicationClass, _ dose: String, _ takenAt: Date) -> Void

    @State private var name = ""
    @State private var medicationClass: MedicationClass = .simpleAnalgesic
    @State private var dose = ""
    @State private var takenAt = Date()

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Common medications") {
                    ForEach(MedicationClass.allCases.filter { !MedicationPreset.presets(for: $0).isEmpty }) { cls in
                        VStack(alignment: .leading, spacing: Brand.Space.xs) {
                            Text(cls.displayName).font(.caption).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(MedicationPreset.presets(for: cls)) { preset in
                                        Button(preset.name) {
                                            Haptics.lightImpact()
                                            name = preset.name
                                            medicationClass = preset.medicationClass
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(name == preset.name ? .mygraPurple : .secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Medication name", text: $name)
                        .accessibilityIdentifier("medicationNameField")
                    Picker("Class", selection: $medicationClass) {
                        ForEach(MedicationClass.allCases) { Text($0.displayName).tag($0) }
                    }
                    TextField("Dose (optional)", text: $dose)
                    DatePicker("Taken at", selection: $takenAt, in: migraine.startDate..., displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Text("Mygra counts the days you take each class so it can warn you before regular use reaches the levels linked to medication-overuse headache. This is general information, not medical advice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, medicationClass, dose, takenAt)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}
#endif
