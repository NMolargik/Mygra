//
//  MainView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData
import WeatherKit
import Combine

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    @Environment(UserManager.self) private var userManager: UserManager
    
    @Binding var pendingDeepLink: DeepLink?

    @State private var appTab: AppTab = .dashboard
    @State private var showingEntrySheet: Bool = false
    @State private var showingOngoingAlert: Bool = false
    @State private var listPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var lastPushedMigraineID: UUID? = nil
    @State private var now: Date = Date()

    var body: some View {
        Group {
            if isRegularWidth {
                NavigationSplitView {
                    NavigationStack {
                        MigraineListView(showingEntrySheet: $showingEntrySheet)
                            .navigationTitle("")
                    }
                } detail: {
                    NavigationStack(path: $listPath) {
                        DashboardView(
                            showingEntrySheet: $showingEntrySheet,
                            onNavigateToMigraine: { migraineID in
                                if lastPushedMigraineID != migraineID {
                                    listPath.append(migraineID)
                                    lastPushedMigraineID = migraineID
                                }
                            },
                            deleteAllMigraines: {
                                deleteAllMigraines()
                            }
                        )
                        .navigationTitle("Mygra")
                        .toolbar { regularWidthTopBarToolbar }
                            .navigationDestination(for: UUID.self) { migraineID in
                                if let migraine = (migraineManager.visibleMigraines.first { $0.id == migraineID }
                                                   ?? migraineManager.migraines.first { $0.id == migraineID }) {
                                    MigraineDetailView(migraine: migraine, onClose: {
                                        if !listPath.isEmpty {
                                            listPath.removeLast()
                                        }
                                    })
                                } else {
                                    ContentUnavailableView(
                                        "Migraine Not Found",
                                        systemImage: "exclamationmark.triangle",
                                        description: Text("The selected migraine could not be loaded.")
                                    )
                                }
                            }
                    }
                }
                .tabViewBottomAccessoryIfAvailable { bottomAccessory }
                .sheet(isPresented: $showingEntrySheet) {
                    MigraineEntryView(onMigraineSaved: { migraine, reviewScene in
                        createNewMigraine(migraine: migraine, reviewScene: reviewScene)
                    })
                    .interactiveDismissDisabled(true)
                    .presentationDetents([.large])
                }
                .onChange(of: listPath) { _, newValue in
                    if newValue.count == 0 {
                        lastPushedMigraineID = nil
                    }
                }
            } else {
                TabView(selection: $appTab) {
                    NavigationStack {
                        DashboardView(
                            showingEntrySheet: $showingEntrySheet,
                            deleteAllMigraines: {
                                deleteAllMigraines()
                            }
                        )
                        .navigationTitle("Mygra")
                        .toolbar { dashboardTopBarToolbar }
                    }
                    .tint(nil)
                    .tabItem {
                        AppTab.dashboard.icon()
                        Text(AppTab.dashboard.rawValue)
                    }
                    .tag(AppTab.dashboard)

                    NavigationStack(path: $calendarPath) {
                        MigraineCalendarView()
                            .navigationDestination(for: UUID.self) { migraineID in
                                if let migraine = (migraineManager.visibleMigraines.first { $0.id == migraineID }
                                                   ?? migraineManager.migraines.first { $0.id == migraineID }) {
                                    MigraineDetailView(migraine: migraine)
                                } else {
                                    ContentUnavailableView(
                                        "Migraine Not Found",
                                        systemImage: "exclamationmark.triangle",
                                        description: Text("The selected migraine could not be loaded.")
                                    )
                                }
                            }
                    }
                    .tint(nil)
                    .tabItem {
                        AppTab.calendar.icon()
                        Text(AppTab.calendar.rawValue)
                    }
                    .tag(AppTab.calendar)

                    NavigationStack(path: $listPath) {
                        MigraineListView(
                            showingEntrySheet: $showingEntrySheet
                        )
                        .navigationTitle(AppTab.list.rawValue)
                        .navigationDestination(for: UUID.self) { migraineID in
                            if let migraine = (migraineManager.visibleMigraines.first { $0.id == migraineID }
                                               ?? migraineManager.migraines.first { $0.id == migraineID }) {
                                MigraineDetailView(migraine: migraine)
                            } else {
                                ContentUnavailableView(
                                    "Migraine Not Found",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text("The selected migraine could not be loaded.")
                                )
                            }
                        }
                        .toolbar { listTopBarToolbar }
                    }
                    .tint(nil)
                    .tabItem {
                        AppTab.list.icon()
                        Text(AppTab.list.rawValue)
                    }
                    .tag(AppTab.list)

                    NavigationStack {
                        SettingsView(
                            onMigrainesDeletionTriggered: {
                                self.deleteAllMigraines()
                            }
                        )
                        .navigationTitle(AppTab.settings.rawValue)
                    }
                    .tint(nil)
                    .tabItem {
                        AppTab.settings.icon()
                        Text(AppTab.settings.rawValue)
                    }
                    .tag(AppTab.settings)
                }
                .tint(appTab.color())
                .tabViewBottomAccessoryIfAvailable { bottomAccessory }
                .sheet(isPresented: $showingEntrySheet) {
                    MigraineEntryView(
                        onMigraineSaved: { migraine, reviewScene in
                        appTab = .list
                        createNewMigraine(migraine: migraine, reviewScene: reviewScene)
                    })
                    .interactiveDismissDisabled(true)
                    .presentationDetents([.large])
                }
                .onChange(of: listPath) { _, newValue in
                    if newValue.count == 0 {
                        lastPushedMigraineID = nil
                    }
                }
            }
        }
        .alert("Ongoing Migraine", isPresented: $showingOngoingAlert) {
            Button("OK", role: .cancel) { }
            if let ongoing = migraineManager.ongoingMigraine {
                Button("View Ongoing") {
                    if !isRegularWidth {
                        appTab = .list
                    }
                    if lastPushedMigraineID != ongoing.id {
                        listPath.append(ongoing.id)
                        lastPushedMigraineID = ongoing.id
                    }
                }
            }
        } message: {
            Text("You already have an ongoing migraine. End it before starting a new one.")
        }
        .onChange(of: pendingDeepLink) { _, newLink in
            handleDeepLink(newLink)
        }
        .onAppear {
            // Handle any pending deep link on appear
            if pendingDeepLink != nil {
                handleDeepLink(pendingDeepLink)
            }
        }
    }
    
    private func handleDeepLink(_ link: DeepLink?) {
        guard let link = link else { return }

        // Reset the deep link after handling
        defer { pendingDeepLink = nil }

        switch link {
        case .newMigraine:
            showingEntrySheet = true
        case .home:
            appTab = .dashboard
        case .list:
            appTab = .list
        case .settings:
            appTab = .settings
        }
    }

    // MARK: - Ongoing accessory
    @ViewBuilder
    private var ongoingAccessory: some View {
        if let ongoing = migraineManager.ongoingMigraine {
            Button {
                if !isRegularWidth {
                    appTab = .list
                }
                if lastPushedMigraineID == ongoing.id {
                    return
                }
                listPath.append(ongoing.id)
                lastPushedMigraineID = ongoing.id
            } label: {
                HStack(spacing: 8) {
                    Group {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "waveform.path.ecg")
                                .symbolVariant(.fill)
                                .foregroundStyle(LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .leading, endPoint: .trailing))
                                .symbolEffect(.breathe.pulse.byLayer, isActive: true)
                        } else {
                            Image(systemName: "waveform.path.ecg")
                                .symbolVariant(.fill)
                                .foregroundStyle(LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .leading, endPoint: .trailing))
                                .symbolEffect(.pulse, value: now)
                        }
                    }

                    Text("Ongoing Migraine")
                        .font(.headline)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(durationString(since: ongoing.startDate, now: now))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Spacer(minLength: 0)
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .onReceive(timer) { tick in
                let quantized = Date(timeIntervalSince1970: floor(tick.timeIntervalSince1970))
                self.now = quantized
            }
        }
    }

    // MARK: - Bottom accessory
    @ViewBuilder
    private var bottomAccessory: some View {
        // If there's an ongoing migraine, show the existing ongoing accessory and nothing else
        if migraineManager.ongoingMigraine != nil {
            ongoingAccessory
        } else if !isRegularWidth {
            // iPhone only (compact width)
            HStack(spacing: 12) {
                // Leading: days since last migraine
                Text(daysSinceLastMigraineString())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                // Trailing: New Migraine button
                Button {
                    handleAddTapped()
                } label: {
                    Text("New Migraine")
                        .bold()
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButtonBottom")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Toolbar helpers
    @ToolbarContentBuilder
    private var dashboardTopBarToolbar: some ToolbarContent {
        if #unavailable(iOS 26) {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddTapped()
                } label: {
                    Text("New Migraine")
                        .bold()
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
            }
        } else if isRegularWidth {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddTapped()
                } label: {
                    Text("New Migraine")
                        .bold()
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
            }
        }
    }

    @ToolbarContentBuilder
    private var listTopBarToolbar: some ToolbarContent {
        if #unavailable(iOS 26) {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddTapped()
                } label: {
                    Label("Add", systemImage: "plus")
                        .bold()
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
            }
        } else if isRegularWidth {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddTapped()
                } label: {
                    Label("Add", systemImage: "plus")
                        .bold()
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
            }
        }
    }

    @ToolbarContentBuilder
    private var regularWidthTopBarToolbar: some ToolbarContent {
        if #unavailable(iOS 26) {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddTapped()
                } label: {
                    Text("New Migraine")
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
            }
        } else if isRegularWidth {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddTapped()
                } label: {
                    Text("New Migraine")
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
            }
        }
    }

    private func daysSinceLastMigraineString() -> String {
        // Determine the most recent migraine end date or start date if never ended
        let lastDate: Date? = {
            // Consider visibleMigraines first; if empty, fall back to all migraines
            let all = migraineManager.visibleMigraines.isEmpty ? migraineManager.migraines : migraineManager.visibleMigraines
            guard !all.isEmpty else { return nil }
            // Sort by the most relevant date: endDate if present, otherwise startDate
            return all
                .compactMap { $0.endDate ?? $0.startDate }
                .max()
        }()

        guard let date = lastDate else {
            return "Streak: 0 days"
        }
        let days = max(0, Int(Date().timeIntervalSince(date) / 86_400))
        if days == 0 {
            return "Streak: 0 days"
        } else if days == 1 {
            return "Streak: 1 day"
        } else {
            return "Streak: \(days) days"
        }
    }

    // MARK: - Helpers

    private var isRegularWidth: Bool {
        hSizeClass == .regular
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    }

    private func durationString(since start: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func handleAddTapped() {
        if migraineManager.ongoingMigraine != nil {
            showingOngoingAlert = true
        } else {
            showingEntrySheet = true
        }
    }

    // MARK: - Deep link processing (from ContentView)

    private func endMigraineIfRequested(for id: UUID, action: String?) {
        guard action?.lowercased() == "end" else { return }
        if let migraine = (migraineManager.visibleMigraines.first { $0.id == id }
                           ?? migraineManager.migraines.first { $0.id == id }) {
            if migraine.endDate == nil {
                migraineManager.update(migraine) { m in
                    m.endDate = Date()
                }
            }
        }
    }
    
    private func createNewMigraine(migraine: Migraine, reviewScene: UIWindowScene?) {
        migraineManager.create(migraine: migraine, reviewScene: reviewScene)
        
        showingEntrySheet = false
        if lastPushedMigraineID != migraine.id {
            listPath.append(migraine.id)
            lastPushedMigraineID = migraine.id
        }
    }

    private func navigateToMigraine(id: UUID) {
        if !isRegularWidth {
            appTab = .list
        }
        // Avoid pushing the same destination twice
        if lastPushedMigraineID == id {
            return
        }
        listPath.append(id)
        lastPushedMigraineID = id
    }
    
    private func deleteAllMigraines() {
        let start = Date()

        Task {
            // Delete all migraines via manager
            await MainActor.run {
                migraineManager.deleteAllMigraines()
            }

            // Ensure at least 2 seconds elapsed to show the deletion UI
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 2.0 {
                let remaining = UInt64((2.0 - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: remaining)
            }

            // Haptic feedback for completion
            await MainActor.run {
                Haptics.success()
            }
        }
    }
}

#Preview("Main – Basic") {
    // Register AppStorage defaults for preview
    UserDefaults.standard.register(defaults: [
        AppStorageKeys.useMetricUnits: false
    ])

    // In-memory model container for preview
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

    // Lightweight managers for environment
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()
    let previewUserManager = UserManager(context: container.mainContext)
    let previewMigraineManager = MigraineManager(context: container.mainContext, healthManager: previewHealthManager)
    let previewInsightManager = InsightManager(
        userManager: previewUserManager,
        migraineManager: previewMigraineManager,
        weatherManager: previewWeatherManager,
        healthManager: previewHealthManager
    )

    return MainView(
        pendingDeepLink: .constant(nil)
    )
    .modelContainer(container)
    .environment(previewInsightManager)
    .environment(previewHealthManager)
    .environment(previewWeatherManager)
    .environment(previewUserManager)
    .environment(previewMigraineManager)
}

