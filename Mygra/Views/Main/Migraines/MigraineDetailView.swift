// Detail view for a Migraine, shows all relevant info.

import SwiftUI

struct MigraineDetailView: View {
    let migraine: Migraine
    
    var body: some View {
        Form {
            Section("General") {
                Text("Date: \(migraine.timestamp, format: .dateTime)")
                if let duration = migraine.duration {
                    Text("Duration: \(duration / 60, specifier: "%.1f") min")
                }
                if let severity = migraine.severity {
                    Text("Severity: \(severity.rawValue)")
                }
                if let notes = migraine.notes {
                    Text("Notes: \(notes)")
                }
            }
            if let symptoms = migraine.symptoms, !symptoms.isEmpty {
                Section("Symptoms") {
                    ForEach(symptoms, id: \.self) { symptom in
                        Text(symptom.name)
                    }
                }
            }
            if let treatments = migraine.treatmentsTaken, !treatments.isEmpty {
                Section("Treatments Taken") {
                    ForEach(treatments, id: \.self) { treatment in
                        Text(treatment.name)
                    }
                }
            }
            // You can add more sections for triggers, environment, etc.
        }
        .navigationTitle("Migraine Details")
    }
}

#Preview {
    let sample = Migraine(
        timestamp: .now,
        severity: .severe,
        notes: "Went outside before migraine.",
        symptoms: ["aura", "nausea"].map { Symptom(name: $0) },
        treatmentsTaken: ["sumatriptan", "rest"].map { Treatment(name: $0) }
    )
    MigraineDetailView(migraine: sample)
}
