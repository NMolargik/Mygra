//
//  IntensityUpdateSheet.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import SwiftUI

/// Sheet for recording a new intensity sample during an ongoing migraine.
struct IntensityUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss

    let migraine: Migraine
    let onSave: (Int, Int, String?) -> Void

    @State private var painLevel: Int
    @State private var stressLevel: Int
    @State private var note: String = ""

    init(migraine: Migraine, onSave: @escaping (Int, Int, String?) -> Void) {
        self.migraine = migraine
        self.onSave = onSave
        // Default to current levels
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

                        // Pain slider
                        Slider(value: Binding(
                            get: { Double(painLevel) },
                            set: { painLevel = Int($0) }
                        ), in: 0...10, step: 1)
                        .tint(Severity.from(painLevel: painLevel).color)

                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

                        // Stress slider
                        Slider(value: Binding(
                            get: { Double(stressLevel) },
                            set: { stressLevel = Int($0) }
                        ), in: 0...10, step: 1)
                        .tint(.purple)

                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

                // Previous samples summary
                if let samples = migraine.intensitySamples, !samples.isEmpty {
                    Section {
                        ForEach(samples.sorted { $0.timestamp > $1.timestamp }.prefix(3)) { sample in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.formattedTimeSinceStart ?? "Start")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

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
                    } header: {
                        Text("Recent Updates")
                    }
                }
            }
            .navigationTitle("Update Intensity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(painLevel, stressLevel, trimmedNote.isEmpty ? nil : trimmedNote)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview("Intensity Update") {
    IntensityUpdateSheet(
        migraine: Migraine(
            startDate: Date(),
            painLevel: 5,
            stressLevel: 5
        ),
        onSave: { _, _, _ in }
    )
}
