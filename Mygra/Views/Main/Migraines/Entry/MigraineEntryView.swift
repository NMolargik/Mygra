//
//  MigraineEntryView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI
import SwiftData
import WeatherKit
import UIKit

struct MigraineEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthManager.self) private var healthManager
    @Environment(WeatherManager.self) private var weatherManager
    
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    var onMigraineSaved: (Migraine, UIWindowScene?) -> Void
    
    @Bindable private var viewModel: ViewModel = ViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Text(viewModel.greeting.isEmpty ? "We’ve got you." : viewModel.greeting)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                
                Section("Duration") {
                    DurationSection(
                        titleStart: "Started",
                        startDate: $viewModel.startDate,
                        isOngoing: $viewModel.isOngoing,
                        endDate: $viewModel.endDate,
                        showLiveActivityNote: true
                    )
                }

                Section("Data Retreival") {
                    // Health capsule
                    HStack(spacing: 10) {
                        if viewModel.isPullingHealth {
                            ProgressView()
                                .controlSize(.small)
                        } else if viewModel.healthError != nil {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        } else if viewModel.didPullHealth {
                            // Determine if we should warn (any of sleep/caffeine/water/calories explicitly 0)
                            let zeroHealthFlag: Bool = {
                                guard let h = healthManager.latestData else { return false }
                                let sleepZero = (h.sleepHours ?? -1) == 0
                                let caffeineZero = (h.caffeineMg ?? -1) == 0
                                let waterZero = (h.waterLiters ?? -1) == 0
                                let caloriesZero = (h.energyKilocalories ?? -1) == 0
                                return sleepZero || caffeineZero || waterZero || caloriesZero
                            }()
                            if zeroHealthFlag {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow.gradient)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green.gradient)
                            }
                        }

                        Text(
                            viewModel.isPullingHealth
                            ? "Pulling from Apple Health"
                            : (
                                viewModel.healthError == nil
                                ? (
                                    Calendar.current.isDateInToday(viewModel.startDate)
                                    ? "Pulled from Apple Health"
                                    : "Health data from \(viewModel.startDate.formatted(date: .abbreviated, time: .omitted))"
                                  )
                                : "Failed to pull from Apple Health"
                              )
                        )
                        .foregroundStyle(viewModel.healthError == nil ? .primary : .secondary)
                        .font(.subheadline)
                        .bold(viewModel.healthError != nil)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.startDate)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                    )

                    if let h = healthManager.latestData, viewModel.healthError == nil {
                        IntakeSection(
                            baseHealth: h,
                            isEditing: $viewModel.isEditingHealthValues,
                            addWater: $viewModel.addWater,
                            addCaffeine: $viewModel.addCaffeine,
                            addFoodKcal: $viewModel.addFood,
                            addSleepHours: $viewModel.addSleepHours,
                            isSaving: viewModel.isSavingHealthEdits,
                            errorMessage: viewModel.healthEditErrorMessage,
                            allAddsAreZero: viewModel.allAddsAreZero,
                            onConfirmAdd: {
                                Haptics.success()
                                withAnimation { viewModel.isEditingHealthValues = false }
                            },
                            onCancel: {
                                Haptics.lightImpact()
                                withAnimation { viewModel.isEditingHealthValues = false }
                            }
                        )
                    }

                    // Weather capsule
                    VStack {
                        HStack(spacing: 10) {
                            if viewModel.isPullingWeather {
                                ProgressView()
                                    .controlSize(.small)
                            } else if viewModel.didPullWeather {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if viewModel.weatherError != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            
                            VStack {
                                Text(
                                    viewModel.isPullingWeather
                                        ? "Pulling local weather"
                                        : (
                                            viewModel.showWeatherBackdateAlert
                                            ? viewModel.weatherBackdateMessage
                                            : (
                                                viewModel.didPullWeather
                                                ? (viewModel.weatherError == nil ? "Pulled local weather" : "Using recent weather")
                                                : "Failed to pull weather"
                                            )
                                        )
                                )
                                .foregroundStyle( (viewModel.didPullWeather || viewModel.showWeatherBackdateAlert) ? .primary : .secondary)
                                .font(.subheadline)
                                .bold(!viewModel.didPullWeather && viewModel.weatherError != nil)
                                
                                Spacer(minLength: 0)
                            }
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 6) {
                            Text(" Weather")
                            Text("•")
                                .accessibilityHidden(true)
                            Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                                .foregroundStyle(.mygraPurple)
                            
                            Spacer()
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                        .padding(.leading, 5)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                    )

                    if viewModel.didPullWeather {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let loc = weatherManager.locationString, !loc.isEmpty {
                                    Label(loc, systemImage: "mappin.and.ellipse")
                                }
                                
                                if let t = weatherManager.temperature {
                                    Label(viewModel.displayTemperature(t, useMetricUnits: useMetricUnits), systemImage: "thermometer.medium")
                                }
                                if let h = weatherManager.humidityPercentString {
                                    Label(h, systemImage: "humidity.fill")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                if let p = weatherManager.pressure {
                                    Label(viewModel.displayPressure(p, useMetricUnits: useMetricUnits), systemImage: "gauge.with.dots.needle.bottom.50percent")
                                }
                                if let c = weatherManager.condition {
                                    Label(c.description.capitalized, systemImage: "cloud.sun")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Experience") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pain Level")
                            Spacer()
                            Text("\(viewModel.painLevel)")
                                .bold()
                                .foregroundStyle(Severity.from(painLevel: $viewModel.painLevel.wrappedValue).color)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.painLevel) },
                                set: { viewModel.painLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(viewModel.gradientColor(for: viewModel.painLevel))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stress Level")
                            Spacer()
                            Text("\(viewModel.stressLevel)")
                                .bold()
                                .foregroundStyle(.indigo)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.stressLevel) },
                                set: { viewModel.stressLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(.indigo)
                    }
                    Toggle("Pin this migraine", isOn: $viewModel.pinned)
                        .onChange(of: $viewModel.pinned.wrappedValue) { _, _ in Haptics.lightImpact() }
                }

                Section("Possible Triggers") {
                    // Search field with inline clear button
                    HStack {
                        TextField("Search triggers", text: $viewModel.triggerSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !viewModel.triggerSearchText.isEmpty {
                            Button {
                                Haptics.lightImpact()
                                viewModel.triggerSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }

                    // Grouped, filtered multi-select list
                    ForEach(MigraineTrigger.Group.allCases, id: \.self) { group in
                        let items = viewModel.filteredTriggers(for: group, search: $viewModel.triggerSearchText.wrappedValue)
                        if !items.isEmpty {
                            DisclosureGroup(group.displayName) {
                                ForEach(items, id: \.self) { trig in
                                    Button {
                                        Haptics.lightImpact()
                                        viewModel.toggleTrigger(trig)
                                    } label: {
                                        HStack {
                                            Text(trig.displayName)
                                            Spacer()
                                            if viewModel.selectedTriggers.contains(trig) {
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

                    // Custom trigger input
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
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 120), spacing: 6)],
                                alignment: .leading,
                                spacing: 6
                            ) {
                                ForEach(Array(viewModel.customTriggers.enumerated()), id: \.offset) { idx, label in
                                    HStack(spacing: 6) {
                                        Text(label)
                                            .font(.caption)
                                            .padding(.vertical, 4)
                                            .padding(.leading, 10)
                                        Button {
                                            Haptics.lightImpact()
                                            viewModel.removeCustomTrigger(at: idx)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 6)
                                    }
                                    .background(
                                        Capsule().fill(Color.secondary.opacity(0.15))
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if viewModel.selectedTriggers.isEmpty && viewModel.customTriggers.isEmpty {
                        Text("No triggers selected").foregroundStyle(.secondary)
                    } else {
                        let total = viewModel.selectedTriggers.count + viewModel.customTriggers.count
                        Text("\(total) selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Food Sensitivities") {
                    TextEditor(text: $viewModel.foodsText)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if $viewModel.foodsText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("List foods eaten around this time (comma or newline separated)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.noteText)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if $viewModel.noteText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Add any details you want to remember")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
            }
            .navigationTitle("New Migraine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.lightImpact()
                        // Clear any staged intake values when abandoning the entry entirely
                        viewModel.addWater = 0
                        viewModel.addFood = 0
                        viewModel.addCaffeine = 0
                        viewModel.addSleepHours = 0
                        viewModel.healthEditErrorMessage = nil
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Haptics.lightImpact()
                        Task {
                            guard viewModel.validateBeforeSave() else {
                                Haptics.error()
                                return
                            }
                            let migraine = await viewModel.createMigraine(using: healthManager, weatherManager: weatherManager, useMetricUnits: useMetricUnits)
                            Haptics.success()
                            onMigraineSaved(migraine, nil)
                        }
                    }
                    .foregroundStyle(.mygraBlue)
                }
            }
        }
        .task {
            viewModel.resetGreeting()
            if viewModel.endDate < viewModel.startDate { viewModel.endDate = viewModel.startDate }
            await viewModel.startHealthFetch(using: healthManager)
            await viewModel.startWeatherFetch(using: weatherManager)
        }
        .alert("Cannot Save", isPresented: $viewModel.showValidationAlert, actions: {
            Button("OK", role: .cancel) {
                Haptics.error()
            }
        }, message: {
            Text(viewModel.validationMessage)
        })
        .presentationDetents([.large])
        // Snap water to new step/range whenever unit preference changes
        .onChange(of: useMetricUnits) { _, _ in
            // Use the stored viewModel here to avoid dynamicMember binding confusion
            viewModel.addWater = viewModel.snap(viewModel.addWater, toStep: viewModel.waterStep(useMetricUnits: useMetricUnits), in: viewModel.waterRange(useMetricUnits: useMetricUnits))
        }
        .onChange(of: viewModel.startDate) { _, _ in
            Task { await viewModel.startHealthFetch(using: healthManager); await viewModel.startWeatherFetch(using: weatherManager) }
        }
        .onChange(of: viewModel.isOngoing) { _, _ in
            Task { await viewModel.startHealthFetch(using: healthManager); await viewModel.startWeatherFetch(using: weatherManager) }
        }
        .onChange(of: viewModel.endDate) { _, _ in
            if !viewModel.isOngoing {
                Task { await viewModel.startHealthFetch(using: healthManager); await viewModel.startWeatherFetch(using: weatherManager) }
            }
        }
    }
}

#Preview("Entry View – Empty State") {
    let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Preview ModelContainer setup failed: \(error)")
        }
    }()

    // Lightweight preview managers
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()

    return MigraineEntryView(onMigraineSaved: { migraine, _ in
        print("Saved migraine in preview: start=\(migraine.startDate), pain=\(migraine.painLevel)")
    })
    .modelContainer(container)
    .environment(previewWeatherManager)
    .environment(previewHealthManager)
    .environment(\.locale, .init(identifier: "en_US"))
}
