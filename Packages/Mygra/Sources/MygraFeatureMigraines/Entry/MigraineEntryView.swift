//
//  MigraineEntryView.swift
//  MygraFeatureMigraines
//
//  The new-migraine form. Health and weather are retrieved for the chosen window and
//  attached to the record on save.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared

public struct MigraineEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthManager.self) private var healthManager
    @Environment(WeatherManager.self) private var weatherManager
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    let onMigraineSaved: (Migraine) -> Void

    @State private var viewModel = ViewModel()

    public init(onMigraineSaved: @escaping (Migraine) -> Void) {
        self.onMigraineSaved = onMigraineSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                Text(viewModel.greeting.isEmpty ? "We've got you." : viewModel.greeting)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .italic()
                    .foregroundStyle(LinearGradient.mygraHorizontal)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)

                Section("Duration") {
                    DurationSection(
                        startTitle: "Started",
                        startDate: $viewModel.startDate,
                        isOngoing: $viewModel.isOngoing,
                        endDate: $viewModel.endDate,
                        showLiveActivityNote: true
                    )
                }

                Section("Data Retrieval") {
                    healthCapsule
                    if let health = healthManager.latestData, viewModel.healthError == nil {
                        IntakeSection(
                            baseHealth: health,
                            isEditing: $viewModel.isEditingIntake,
                            additions: $viewModel.additions,
                            onConfirmAdd: {
                                Haptics.success()
                                withAnimation { viewModel.isEditingIntake = false }
                            },
                            onCancel: { viewModel.clearStagedIntake() }
                        )
                    }
                    weatherCapsule
                    if viewModel.didPullWeather, let reading = weatherManager.reading {
                        weatherSummary(reading)
                    }
                }

                Section("Experience") {
                    LevelSlider.pain(level: $viewModel.painLevel)
                    LevelSlider.stress(level: $viewModel.stressLevel)
                    Toggle("Pin this migraine", isOn: $viewModel.pinned)
                        .onChange(of: viewModel.pinned) { _, _ in Haptics.lightImpact() }
                }

                Section("Possible Triggers") {
                    SearchField("Search triggers", text: $viewModel.triggerSearchText)
                    TriggerPickerSection(selection: $viewModel.selectedTriggers, searchText: viewModel.triggerSearchText)
                    customTriggerEditor
                    if viewModel.selectedTriggerCount == 0 {
                        Text("No triggers selected").foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.selectedTriggerCount) selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Food Sensitivities") {
                    TextEditor(text: $viewModel.foodsText)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if viewModel.foodsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                placeholder("List foods eaten around this time (comma or newline separated)")
                            }
                        }
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.noteText)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                placeholder("Add any details you want to remember")
                            }
                        }
                }
            }
            .navigationTitle("New Migraine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.lightImpact()
                        viewModel.clearStagedIntake()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isOngoing ? "Start" : "Submit") {
                        Haptics.lightImpact()
                        Task {
                            guard viewModel.validateBeforeSave() else {
                                Haptics.error()
                                return
                            }
                            let migraine = await viewModel.makeMigraine(using: healthManager, weatherManager: weatherManager)
                            Haptics.success()
                            onMigraineSaved(migraine)
                        }
                    }
                    .foregroundStyle(.mygraBlue)
                }
            }
        }
        .task {
            viewModel.resetGreeting()
            if viewModel.endDate < viewModel.startDate { viewModel.endDate = viewModel.startDate }
            await refreshRetrieval()
        }
        .alert("Cannot Save", isPresented: $viewModel.showValidationAlert) {
            Button("OK", role: .cancel) { Haptics.error() }
        } message: {
            Text(viewModel.validationMessage)
        }
        .alert("Health Data", isPresented: $viewModel.showHealthInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.healthInfoMessage)
        }
        .presentationDetents([.large])
        .onChange(of: viewModel.startDate) { _, _ in Task { await refreshRetrieval() } }
        .onChange(of: viewModel.isOngoing) { _, _ in Task { await refreshRetrieval() } }
        .onChange(of: viewModel.endDate) { _, _ in
            if !viewModel.isOngoing { Task { await refreshRetrieval() } }
        }
    }

    private func refreshRetrieval() async {
        await viewModel.startHealthFetch(using: healthManager)
        await viewModel.startWeatherFetch(using: weatherManager)
    }

    // MARK: - Capsules

    private var healthCapsule: some View {
        let zeroMetrics = viewModel.zeroIntakeMetrics(in: healthManager.latestData)
        return HStack(spacing: 10) {
            if viewModel.isPullingHealth {
                ProgressView().controlSize(.small)
            } else if viewModel.healthError != nil {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            } else if viewModel.didPullHealth {
                if zeroMetrics.isEmpty {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green.gradient)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow.gradient)
                }
            }

            Text(viewModel.healthStatusText(latest: healthManager.latestData))
                .foregroundStyle(viewModel.healthError == nil ? .primary : .secondary)
                .font(.subheadline)
                .bold(viewModel.healthError != nil)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.startDate)

            Spacer(minLength: 0)

            if !viewModel.isPullingHealth && (viewModel.healthError != nil || !zeroMetrics.isEmpty) {
                Button {
                    viewModel.presentHealthInfo(latest: healthManager.latestData)
                } label: {
                    Image(systemName: "info.circle.fill").foregroundStyle(.yellow.gradient)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(.thinMaterial))
    }

    private var weatherCapsule: some View {
        VStack {
            HStack(spacing: 10) {
                if viewModel.isPullingWeather {
                    ProgressView().controlSize(.small)
                } else if viewModel.didPullWeather {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if viewModel.weatherError != nil {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }

                Text(viewModel.weatherStatusText())
                    .foregroundStyle((viewModel.didPullWeather || viewModel.showWeatherBackdateAlert) ? .primary : .secondary)
                    .font(.subheadline)
                    .bold(!viewModel.didPullWeather && viewModel.weatherError != nil)

                Spacer()
            }

            WeatherAttributionView()
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.top, 2)
                .padding(.leading, 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(.thinMaterial))
    }

    private func weatherSummary(_ reading: WeatherReading) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                if let location = weatherManager.locationString, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
                Label(reading.formattedTemperature(useMetricUnits: useMetricUnits), systemImage: "thermometer.medium")
                Label(reading.formattedHumidity, systemImage: "humidity.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Label(reading.formattedPressure(useMetricUnits: useMetricUnits), systemImage: "gauge.with.dots.needle.bottom.50percent")
                Label(reading.condition.displayName, systemImage: "cloud.sun")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    // MARK: - Custom triggers

    private var customTriggerEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add custom trigger", text: $viewModel.customTriggerInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { viewModel.addCustomTrigger() }
                Button {
                    Haptics.lightImpact()
                    viewModel.addCustomTrigger()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(viewModel.customTriggerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !viewModel.customTriggers.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(Array(viewModel.customTriggers.enumerated()), id: \.offset) { index, label in
                        HStack(spacing: 6) {
                            Text(label)
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.leading, 10)
                            Button {
                                Haptics.lightImpact()
                                viewModel.removeCustomTrigger(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 6)
                        }
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func placeholder(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.leading, 5)
    }
}

#Preview("Entry View") {
    MigraineEntryView(onMigraineSaved: { _ in })
        .previewEnvironment()
}
#endif
