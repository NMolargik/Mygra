// Create a reusable view for rendering a Migraine row. Display timestamp, severity, and maybe 1-2 symptoms at a glance.

import SwiftUI

struct MigraineRowView: View {
    let migraine: Migraine
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .foregroundStyle(migraine.severity?.color ?? .green)
                .frame(width: 5)
                .cornerRadius(5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(migraine.timestamp, format: .dateTime.year().month().day())
                    .font(.headline)
                
                HStack {
                    if migraine.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                    }
                    
                    if let symptoms = migraine.symptoms, !symptoms.isEmpty {
                        Text(symptoms.prefix(2).map { $0.name }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    // Example Migraine row preview with some sample data
    let sample = Migraine(
        timestamp: .now,
        severity: .moderate,
        symptoms: ["aura", "nausea"].map { Symptom(name: $0) }
    )
    ScrollView {
        MigraineRowView(migraine: sample)
        MigraineRowView(migraine: sample)
        MigraineRowView(migraine: sample)
        MigraineRowView(migraine: sample)
        Spacer()
    }
    .padding()
}
