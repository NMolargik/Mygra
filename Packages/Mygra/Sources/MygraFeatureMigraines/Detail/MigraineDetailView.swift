//
//  MigraineDetailView.swift
//  MygraFeatureMigraines
//
//  One migraine: timing and levels, the intensity chart, the AI insight, note,
//  triggers, weather, and health — with end / modify / delete / pin actions.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared
import os

public struct MigraineDetailView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(InsightModel.self) private var insights
    @Environment(WeatherManager.self) private var weatherManager
    @Environment(HealthManager.self) private var healthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    let migraine: Migraine
    /// Regular-width hosts supply a close action for the leading toolbar button.
    var onClose: (() -> Void)?

    @State private var showingEndSheet = false
    @State private var endError: String?
    @State private var showDeleteConfirm = false
    @State private var showingModifySheet = false
    @State private var showingIntensitySheet = false
    @State private var showPastWeatherAlert = false

    public init(migraine: Migraine, onClose: (() -> Void)? = nil) {
        self.migraine = migraine
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MigraineDetailHeaderView(
                    migraine: migraine,
                    startText: DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates),
                    endText: migraine.endDate.map { DateFormatting.dateTime($0, useDMY: useDayMonthYearDates) } ?? String(localized: "Ongoing"),
                    durationText: MigraineDates.durationString((migraine.endDate ?? Date()).timeIntervalSince(migraine.startDate)),
                    endError: endError,
                    onEndTap: { showingEndSheet = true }
                )

                IntensityChartView(
                    samples: migraine.intensitySamples ?? [],
                    onUpdateIntensity: migraine.isOngoing ? { showingIntensitySheet = true } : nil
                )

                InsightSectionView(migraine: migraine)

                if let note = migraine.note, !note.isEmpty {
                    NoteDetailView(note: note)
                }
                if !migraine.triggers.isEmpty || !migraine.customTriggers.isEmpty {
                    TriggersDetailView(triggers: migraine.triggers, customTriggers: migraine.customTriggers)
                }
                if let weather = migraine.weather {
                    WeatherDetailView(weather: weather, useMetricUnits: useMetricUnits)
                }
                if let health = migraine.health {
                    HealthDetailView(health: health, useMetricUnits: useMetricUnits)
                }
            }
            .padding()
        }
        .navigationTitle("Migraine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(horizontalSizeClass == .regular)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingIntensitySheet) {
            IntensityUpdateSheet(migraine: migraine) { pain, stress, note in
                migraineData.addIntensitySample(to: migraine, painLevel: pain, stressLevel: stress, note: note)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingEndSheet) {
            EndMigraineSheet(startDate: migraine.startDate, initialEndDate: defaultEndDate) { selected in
                endError = nil
                guard selected >= migraine.startDate else {
                    endError = String(localized: "End time must be after the start time.")
                    return
                }
                migraineData.update(migraine) { $0.endDate = selected }
                showingEndSheet = false
                close()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingModifySheet) {
            ModifyMigraineSheetView(
                migraine: migraine,
                onCancel: { showingModifySheet = false },
                onSave: { edits in
                    apply(edits)
                    showingModifySheet = false
                }
            )
        }
        .alert("Delete this migraine?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                migraineData.delete(migraine)
                close()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Weather", isPresented: $showPastWeatherAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Weather isn't attached for past start dates.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if horizontalSizeClass == .regular {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: close) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                migraineData.togglePinned(migraine)
            } label: {
                Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(migraine.isPinned ? .yellow : .secondary)
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel(migraine.isPinned ? "Unpin migraine" : "Pin migraine")
            .accessibilityHint("Pinned migraines appear at the top of the list")
        }
        if !migraine.isOngoing {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingModifySheet = true
                } label: {
                    Label("Modify", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("modifyMigraineButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Migraine", systemImage: "trash")
                }
                .tint(.red)
                .accessibilityIdentifier("deleteMigraineButton")
            }
        }
    }

    // MARK: - Actions

    private var defaultEndDate: Date {
        max(Date(), migraine.startDate.addingTimeInterval(60))
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    /// Persists the edits, writes staged intake to Health, regenerates the insight, and
    /// refreshes the health/weather snapshots for the edited window.
    private func apply(_ edits: MigraineEdits) {
        migraineData.update(migraine) { m in
            m.startDate = edits.startDate
            m.endDate = edits.endDate
            m.painLevel = edits.painLevel
            m.stressLevel = edits.stressLevel
            m.triggers = Array(edits.triggers)
        }

        Task {
            if !edits.additions.isEmpty {
                do {
                    try await healthManager.save(edits.additions, on: edits.startDate)
                } catch {
                    Log.app.error("Failed to save staged HealthKit intake: \(error.localizedDescription)")
                }
            }

            do {
                let health = try await healthManager.fetchSnapshot(forMigraineStart: edits.startDate)
                migraineData.update(migraine) { $0.health = health }
            } catch {
                Log.app.error("Failed to fetch Health snapshot for edited migraine: \(error.localizedDescription)")
            }

            if Calendar.current.isDateInToday(edits.startDate) {
                await weatherManager.refresh()
                if let weather = weatherManager.makeWeatherData(createdAt: edits.startDate) {
                    migraineData.update(migraine) { $0.weather = weather }
                }
            } else if migraine.weather != nil {
                migraineData.update(migraine) { $0.weather = nil }
                showPastWeatherAlert = true
            }

            await insights.regenerateInsight(for: migraine)
        }
    }
}

#Preview("Migraine Detail") {
    let env = PreviewEnvironment()
    return NavigationStack {
        MigraineDetailView(migraine: env.migraineData.migraines.first!)
    }
    .previewEnvironment(env)
}
#endif
