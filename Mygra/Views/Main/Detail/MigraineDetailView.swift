//
//  MigraineDetailView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import WeatherKit

struct MigraineDetailView: View {
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    @Environment(InsightManager.self) private var insightManager: InsightManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false
    @AppStorage("useDayMonthYearDates") private var useDayMonthYearDates: Bool = false
    
    let migraine: Migraine
    var onClose: (() -> Void)? = nil
    
    @State private var showingEndSheet = false
    @State private var proposedEndDate: Date = Date()
    @State private var endError: String?
    @State private var showDeleteConfirm = false
    @State private var showingModifySheet = false
    @State private var editStartDate: Date = Date()
    @State private var editEndDate: Date = Date()
    @State private var editIsOngoing: Bool = false
    @State private var editPainLevel: Int = 0
    @State private var editStressLevel: Int = 0
    @State private var selectedEditTriggers: Set<MigraineTrigger> = []
    @State private var modifyError: String?
    
    // Helper to seed edit state from migraine
    private func seedEditState() {
        editStartDate = migraine.startDate
        editEndDate = migraine.endDate ?? Date()
        editIsOngoing = (migraine.endDate == nil)
        editPainLevel = migraine.painLevel
        editStressLevel = migraine.stressLevel
        selectedEditTriggers = Set(migraine.triggers)
        modifyError = nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                
                insightSection
                
                if migraine.note?.isEmpty == false {
                    infoCard(title: "Note") {
                        Text(migraine.note!)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if !migraine.triggers.isEmpty || !migraine.customTriggers.isEmpty {
                    infoCard(title: "Triggers") {
                        VStack(alignment: .leading, spacing: 8) {
                            if !migraine.triggers.isEmpty {
                                ForEach(migraine.triggers, id: \.self) { t in
                                    Label(t.displayName, systemImage: "bolt.heart")
                                }
                            }
                            if !migraine.customTriggers.isEmpty {
                                ForEach(migraine.customTriggers, id: \.self) { t in
                                    Label(t, systemImage: "bolt.heart")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if let wx = migraine.weather {
                    infoCard(title: "Weather", trailing: {
                        HStack(spacing: 6) {
                            Text(" Weather")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("•")
                                .accessibilityHidden(true)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                                .font(.caption2)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let place = wx.locationDescription, !place.isEmpty {
                                LabeledRow("Location", value: place)
                            }
                            
                            LabeledRow("Condition", value: wx.condition.description)
                            LabeledRow("Temperature") {
                                let temp = wx.displayTemperature(useMetricUnits: useMetricUnits)
                                let unit = useMetricUnits ? "°C" : "°F"
                                Text("\(Int(round(temp))) \(unit)")
                            }
                            LabeledRow("Humidity", value: "\(Int(wx.humidityPercent))%")
                            LabeledRow("Pressure") {
                                let pressure = wx.displayBarometricPressure(useMetricUnits: useMetricUnits)
                                if useMetricUnits {
                                    Text(String(format: "%.0f hPa", pressure))
                                } else {
                                    Text(String(format: "%.2f inHg", pressure))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if let h = migraine.health {
                    infoCard(title: "Health") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let w = h.waterLiters {
                                if useMetricUnits {
                                    LabeledRow("Water", value: String(format: "%.1f L", w))
                                } else {
                                    let flOz = w * 33.8140227
                                    LabeledRow("Water", value: String(format: "%.0f fl oz", flOz))
                                }
                            }
                            if let s = h.sleepHours {
                                LabeledRow("Sleep", value: String(format: "%.1f h", s))
                            }
                            if let kcal = h.energyKilocalories {
                                LabeledRow("Food", value: String(format: "%.0f cal", kcal))
                            }
                            if let caf = h.caffeineMg {
                                LabeledRow("Caffeine", value: String(format: "%.0f mg", caf))
                            }
                            if let steps = h.stepCount {
                                LabeledRow("Steps", value: "\(steps)")
                            }
                            if let rhr = h.restingHeartRate {
                                LabeledRow("Resting HR", value: "\(rhr) bpm")
                            }
                            if let ahr = h.activeHeartRate {
                                LabeledRow("Active HR", value: "\(ahr) bpm")
                            }
                            if let phase = h.menstrualPhase {
                                LabeledRow("Menstrual Phase", value: phase.rawValue)
                            }
                            if let glucose = h.glucoseMgPerdL {
                                if useMetricUnits {
                                    let mmol = glucose / 18.0
                                    LabeledRow("Glucose", value: String(format: "%.1f mmol/L", mmol))
                                } else {
                                    LabeledRow("Glucose", value: String(format: "%.0f mg/dL", glucose.rounded()))
                                }
                            }
                            if let spo2Fraction = h.bloodOxygenPercent {
                                let percent = spo2Fraction * 100.0
                                if percent.truncatingRemainder(dividingBy: 1) == 0 {
                                    LabeledRow("Oxygen Saturation", value: "\(Int(percent))%")
                                } else {
                                    LabeledRow("Oxygen Saturation", value: String(format: "%.1f%%", percent))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer(minLength: 12)
                
                // Delete button at the very bottom
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Migraine", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityIdentifier("deleteMigraineButton")
            }
            .padding()
        }
        .navigationTitle("Migraine")
        .navigationBarTitleDisplayMode(.inline)
        // iPad-only Close button in the leading position, pin in trailing
        .toolbar {
            if hSizeClass == .regular {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Close")
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    migraineManager.togglePinned(migraine)
                } label: {
                    Image(systemName: migraine.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(migraine.pinned ? .yellow : .secondary)
                }
                .accessibilityLabel(migraine.pinned ? "Unpin" : "Pin")
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    seedEditState()
                    showingModifySheet = true
                } label: {
                    Label("Modify", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("modifyMigraineButton")
            }
        }
        .sheet(isPresented: $showingEndSheet) {
            EndMigraineSheet(
                startDate: migraine.startDate,
                initialEndDate: defaultEndDate,
                onConfirm: { selected in
                    endError = nil
                    guard selected >= migraine.startDate else {
                        endError = "End time must be after the start time."
                        return
                    }
                    migraineManager.update(migraine) { m in
                        m.endDate = selected
                    }
                    dismiss()
                },
                onCancel: { /* simply closes */ }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingModifySheet) {
            NavigationStack {
                Form {
                    Section("Duration") {
                        DatePicker(
                            "Start",
                            selection: $editStartDate,
                            in: (Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Toggle("Ongoing", isOn: $editIsOngoing)
                        if !editIsOngoing {
                            DatePicker(
                                "End",
                                selection: $editEndDate,
                                in: editStartDate...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                        if let err = modifyError {
                            Text(err).font(.footnote).foregroundStyle(.red)
                        }
                    }

                    Section("Experience") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Pain Level")
                                Spacer()
                                Text("\(editPainLevel)")
                                    .bold()
                                    .foregroundStyle(Severity.from(painLevel: editPainLevel).color)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(editPainLevel) },
                                    set: { editPainLevel = Int(round($0)) }
                                ),
                                in: 0...10,
                                step: 1
                            )
                            .tint(Severity.from(painLevel: editPainLevel).color)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Stress Level")
                                Spacer()
                                Text("\(editStressLevel)")
                                    .bold()
                                    .foregroundStyle(.indigo)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(editStressLevel) },
                                    set: { editStressLevel = Int(round($0)) }
                                ),
                                in: 0...10,
                                step: 1
                            )
                            .tint(.indigo)
                        }
                    }

                    Section("Triggers") {
                        ForEach(MigraineTrigger.Group.allCases, id: \.self) { group in
                            let items = MigraineTrigger.allCases.filter { $0.group == group }
                            if !items.isEmpty {
                                DisclosureGroup(group.displayName) {
                                    ForEach(items, id: \.self) { trig in
                                        Button {
                                            if selectedEditTriggers.contains(trig) {
                                                selectedEditTriggers.remove(trig)
                                            } else {
                                                selectedEditTriggers.insert(trig)
                                            }
                                            Haptics.lightImpact()
                                        } label: {
                                            HStack {
                                                Text(trig.displayName)
                                                Spacer()
                                                if selectedEditTriggers.contains(trig) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.red)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundStyle(.red)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        if selectedEditTriggers.isEmpty {
                            Text("No triggers selected").foregroundStyle(.secondary)
                        } else {
                            Text("\(selectedEditTriggers.count) selected")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Modify Migraine")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            Haptics.lightImpact()
                            showingModifySheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Haptics.lightImpact()
                            modifyError = nil
                            let earliest = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            let now = Date()
                            guard editStartDate >= earliest else {
                                modifyError = "Start time cannot be more than 1 day in the past."
                                Haptics.error()
                                return
                            }
                            guard editStartDate <= now else {
                                modifyError = "Start time cannot be in the future."
                                Haptics.error()
                                return
                            }
                            if !editIsOngoing {
                                if editEndDate < editStartDate {
                                    modifyError = "End time must be after the start time."
                                    Haptics.error()
                                    return
                                }
                                if editEndDate > now {
                                    modifyError = "End time cannot be in the future."
                                    Haptics.error()
                                    return
                                }
                            }

                            // Persist edits and refresh via manager
                            migraineManager.update(migraine) { m in
                                m.startDate = editStartDate
                                m.endDate = editIsOngoing ? nil : editEndDate
                                m.painLevel = editPainLevel
                                m.stressLevel = editStressLevel
                                m.triggers = Array(selectedEditTriggers)
                            }

                            // Re-generate insight
                            Task {
                                await insightManager.handleJustCreatedMigraine(migraine)
                            }

                            showingModifySheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        
.onChange(of: showingModifySheet) { _, newValue in
    if newValue {
        seedEditState()
    }
}
        .alert("Delete this migraine?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                migraineManager.delete(migraine)
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            // Initialize proposed end date when showing the view
            proposedEndDate = defaultEndDate
        }
    }
    
    // MARK: - Insight section (Apple Intelligence)
    private var insightSection: some View {
        Group {
            let isGenerating = insightManager.isGeneratingGuidance && insightManager.isGeneratingGuidanceFor?.id == migraine.id
            if isGenerating || (migraine.insight?.isEmpty == false) {
                infoCard(title: "Insight") {
                    VStack(alignment: .leading, spacing: 8) {
                        // Header row indicating Apple Intelligence
                        HStack(spacing: 6) {
                            Image(systemName: "apple.intelligence")
                                .foregroundStyle(
                                    AngularGradient(
                                        colors: [.orange, .red, .purple, .blue, .purple, .red, .orange, .orange],
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(270)
                                    )
                                )
                            Text("Powered by Apple Intelligence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        
                        if isGenerating && (migraine.insight?.isEmpty ?? true) {
                            // Loading placeholder while generating
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Generating insight…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                // Subtle animated placeholder lines
                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(width: 220, height: 10)
                                }
                                .redacted(reason: .placeholder)
                                .shimmer()
                            }
                        } else if let text = migraine.insight, !text.isEmpty {
                            Text(text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                if migraine.isOngoing {
                    Text("Ongoing Migraine")
                        .font(.title2).bold()
                }
                Spacer()
            }
            
            HStack(spacing: 12) {
                infoPill(
                    title: "Pain",
                    value: "\(migraine.painLevel)",
                    icon: "face.dashed",
                    tint: migraine.severity.color
                )
                infoPill(
                    title: "Stress",
                    value: "\(migraine.stressLevel)",
                    icon: "brain.head.profile",
                    tint: .purple
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                LabeledRow("Start", value: DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates))
                LabeledRow("End", value: migraine.endDate.map { DateFormatting.dateTime($0, useDMY: useDayMonthYearDates) } ?? "Ongoing")
                if let end = migraine.endDate {
                    LabeledRow("Duration", value: formatDuration(from: migraine.startDate, to: end))
                } else {
                    // Live duration not ticking here to keep detail static; could be added if desired.
                    LabeledRow("Duration", value: formatLiveDuration(since: migraine.startDate))
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            if migraine.isOngoing {
                Button {
                    proposedEndDate = defaultEndDate
                    showingEndSheet = true
                } label: {
                    Label("End Migraine", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .accessibilityIdentifier("endMigraineButton")
            }
            
            if let error = endError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
    
    private func infoCard<Content: View, Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                trailing()
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
    
    private func infoPill(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .contentShape(Rectangle())
    }
    
    private var defaultEndDate: Date {
        let now = Date()
        return max(now, migraine.startDate.addingTimeInterval(60)) // ensure at least 1 min after start
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = max(0, Int(end.timeIntervalSince(start)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
    
    private func formatLiveDuration(since start: Date) -> String {
        let interval = max(0, Int(Date().timeIntervalSince(start)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
}
