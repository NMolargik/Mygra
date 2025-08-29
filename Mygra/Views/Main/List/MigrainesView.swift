//
//  MigrainesView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import WeatherKit

struct MigrainesView: View {
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    
    var body: some View {
        Group {
            if migraineManager.visibleMigraines.isEmpty {
                ContentUnavailableView("No Migraines Yet",
                                       systemImage: "list.bullet.rectangle",
                                       description: Text("Your logged migraines will appear here."))
            } else {
                List(migraineManager.visibleMigraines) { migraine in
                    NavigationLink {
                        MigraineDetailView(migraine: migraine)
                    } label: {
                        MigraineRow(migraine: migraine)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Migraines")
    }
}

private struct MigraineRow: View {
    let migraine: Migraine
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(migraine.severity.color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateRangeText)
                        .font(.headline)
                        .lineLimit(1)
                    if migraine.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Pain \(migraine.painLevel)")
                        .font(.subheadline)
                        .foregroundStyle(migraine.severity.color)
                        .bold()
                }
                
                HStack(spacing: 8) {
                    if !migraine.triggers.isEmpty {
                        Text(triggerSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let note = migraine.note, !note.isEmpty {
                        Text("• \(note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private var dateRangeText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let start = df.string(from: migraine.startDate)
        if let end = migraine.endDate {
            return "\(start) – \(df.string(from: end))"
        } else {
            return "\(start) – ongoing"
        }
    }
    
    private var triggerSummary: String {
        let names = migraine.triggers.prefix(3).map { $0.displayName }
        var text = names.joined(separator: ", ")
        if migraine.triggers.count > 3 {
            text += " +\(migraine.triggers.count - 3)"
        }
        return text
    }
}

struct MigraineDetailView: View {
    let migraine: Migraine
    
    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Start", value: format(date: migraine.startDate))
                LabeledContent("End", value: migraine.endDate.map { format(date: $0) } ?? "Ongoing")
                LabeledContent("Pain Level") { Text("\(migraine.painLevel)").foregroundStyle(migraine.severity.color) }
                LabeledContent("Stress Level", value: "\(migraine.stressLevel)")
                if migraine.pinned {
                    LabeledContent("Pinned") { Image(systemName: "pin.fill") }
                }
            }
            
            if let note = migraine.note, !note.isEmpty {
                Section("Note") {
                    Text(note)
                }
            }
            
            if let insight = migraine.insight, !insight.isEmpty {
                Section("Insight") {
                    Text(insight)
                }
            }
            
            if !migraine.triggers.isEmpty {
                Section("Triggers") {
                    ForEach(migraine.triggers, id: \.self) { t in
                        Text(t.displayName)
                    }
                }
            }
            
            if !migraine.foodsEaten.isEmpty {
                Section("Foods Eaten") {
                    ForEach(migraine.foodsEaten, id: \.self) { f in
                        Text(f)
                    }
                }
            }
            
            if let wx = migraine.weather {
                Section("Weather") {
                    LabeledContent("Condition", value: wx.condition.description)
                    LabeledContent("Temperature", value: "\(Int(wx.temperatureCelsius)) °C")
                    LabeledContent("Humidity", value: "\(Int(wx.humidityPercent))%")
                    LabeledContent("Pressure", value: String(format: "%.0f hPa", wx.barometricPressureHpa))
                }
            }
            
            if let h = migraine.health {
                Section("Health") {
                    if let w = h.waterLiters { LabeledContent("Water", value: String(format: "%.1f L", w)) }
                    if let s = h.sleepHours { LabeledContent("Sleep", value: String(format: "%.1f h", s)) }
                    if let kcal = h.energyKilocalories { LabeledContent("Energy", value: String(format: "%.0f kcal", kcal)) }
                    if let caf = h.caffeineMg { LabeledContent("Caffeine", value: String(format: "%.0f mg", caf)) }
                    if let steps = h.stepCount { LabeledContent("Steps", value: "\(steps)") }
                    if let rhr = h.restingHeartRate { LabeledContent("Resting HR", value: "\(rhr) bpm") }
                    if let ahr = h.activeHeartRate { LabeledContent("Active HR", value: "\(ahr) bpm") }
                    if let phase = h.menstrualPhase { LabeledContent("Phase", value: phase.rawValue) }
                }
            }
        }
        .navigationTitle("Migraine")
    }
    
    private func format(date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

#Preview {
    // Minimal preview showing empty state unless environment is provided by MainView preview.
    NavigationStack {
        MigrainesView()
    }
}
