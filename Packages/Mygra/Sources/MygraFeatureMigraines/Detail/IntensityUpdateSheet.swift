//
//  IntensityUpdateSheet.swift
//  MygraFeatureMigraines
//
//  Records a new intensity sample during an ongoing migraine.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct IntensityUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss

    let migraine: Migraine
    let onSave: (_ painLevel: Int, _ stressLevel: Int, _ note: String?) -> Void

    @State private var painLevel: Int
    @State private var stressLevel: Int
    @State private var note = ""

    init(migraine: Migraine, onSave: @escaping (Int, Int, String?) -> Void) {
        self.migraine = migraine
        self.onSave = onSave
        _painLevel = State(initialValue: migraine.painLevel)
        _stressLevel = State(initialValue: migraine.stressLevel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How is your pain right now?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Pain Level: \(painLevel)")
                                .font(.headline)
                                .foregroundStyle(Severity.from(painLevel: painLevel).color)
                            Spacer()
                            Stepper("", value: $painLevel, in: 0...10)
                                .labelsHidden()
                        }
                        Slider(value: Binding(get: { Double(painLevel) }, set: { painLevel = Int($0) }), in: 0...10, step: 1)
                            .tint(Severity.from(painLevel: painLevel).color)
                        scaleLabels
                    }
                } header: {
                    Label("Pain", systemImage: "bolt.fill")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How stressed are you feeling?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Stress Level: \(stressLevel)")
                                .font(.headline)
                                .foregroundStyle(.purple)
                            Spacer()
                            Stepper("", value: $stressLevel, in: 0...10)
                                .labelsHidden()
                        }
                        Slider(value: Binding(get: { Double(stressLevel) }, set: { stressLevel = Int($0) }), in: 0...10, step: 1)
                            .tint(.purple)
                        scaleLabels
                    }
                } header: {
                    Label("Stress", systemImage: "brain.head.profile")
                }

                Section {
                    TextField("How are you feeling?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Label("Quick Note (Optional)", systemImage: "note.text")
                }

                if !migraine.sortedIntensitySamples.isEmpty {
                    Section("Recent Updates") {
                        ForEach(migraine.sortedIntensitySamples.reversed().prefix(3)) { sample in
                            HStack {
                                Text(sample.formattedTimeSinceStart ?? String(localized: "Start"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 12) {
                                    Label("\(sample.painLevel)", systemImage: "bolt.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.red)
                                    Label("\(sample.stressLevel)", systemImage: "brain.head.profile")
                                        .font(.subheadline)
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Update Intensity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(painLevel, stressLevel, trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var scaleLabels: some View {
        HStack {
            Text("0").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("10").font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview("Intensity Update") {
    IntensityUpdateSheet(migraine: Migraine.sampleOngoing(), onSave: { _, _, _ in })
}
#endif
