//
//  MainView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData
import WeatherKit

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
    @State private var showingAssistant: Bool = false
    @State private var listPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var lastPushedMigraineID: UUID? = nil

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
                        .toolbar { addMigraineToolbar(title: "New Migraine") }
                        .navigationDestination(for: UUID.self) { migraineID in
                            migraineDestination(for: migraineID, onClose: {
                                if !listPath.isEmpty {
                                    listPath.removeLast()
                                }
                            })
                        }
                    }
                }
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
                        .toolbar { addMigraineToolbar(title: "New Migraine") }
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
                                migraineDestination(for: migraineID)
                            }
                            .toolbar { addMigraineToolbar(title: "New Migraine") }
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
                            migraineDestination(for: migraineID)
                        }
                        .toolbar { addMigraineToolbar(title: "New Migraine") }
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
        .sheet(isPresented: $showingAssistant) {
            if #available(iOS 26.0, *) {
                MigraineAssistantView()
            }
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
            handleAddTapped()
        case .home:
            appTab = .dashboard
        case .calendar:
            appTab = .calendar
        case .list:
            appTab = .list
        case .settings:
            appTab = .settings
        case .migraine(let id):
            navigateToMigraine(id: id)
        case .assistant:
            if #available(iOS 26.0, *) {
                showingAssistant = true
            }
        case .endOngoing:
            migraineManager.endOngoingMigraine()
        }
    }

    // MARK: - Toolbar / navigation helpers

    /// Top-trailing toolbar item shown on the Dashboard, Calendar, and
    /// Migraines pages. When a migraine is ongoing it surfaces a tappable
    /// pulsing indicator (jumping to that migraine); otherwise it offers the
    /// "New Migraine" action.
    @ToolbarContentBuilder
    private func addMigraineToolbar(title: LocalizedStringKey, systemImage: String? = nil) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let ongoing = migraineManager.ongoingMigraine {
                ongoingMigraineButton(for: ongoing)
            } else {
                Button {
                    handleAddTapped()
                } label: {
                    if let systemImage {
                        Label(title, systemImage: systemImage)
                            .bold()
                            .foregroundStyle(.mygraBlue)
                    } else {
                        Text(title)
                            .bold()
                            .foregroundStyle(.mygraBlue)
                    }
                }
                .accessibilityIdentifier("addEntryButton")
                .accessibilityLabel(Text("Log a new migraine"))
            }
        }
    }

    /// The pulsing "ongoing migraine" indicator that replaces the add button
    /// while a migraine is in progress. Tapping it opens that migraine.
    private func ongoingMigraineButton(for ongoing: Migraine) -> some View {
        Button {
            navigateToMigraine(id: ongoing.id)
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .symbolVariant(.fill)
                        .foregroundStyle(LinearGradient(colors: [.mygraPurple, .mygraBlue], startPoint: .leading, endPoint: .trailing))
                        .symbolEffect(.pulse, options: .repeating)
                    Text(MigraineDates.elapsedString(since: ongoing.startDate, now: context.date))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("ongoingMigraineButton")
        .accessibilityLabel(Text("Ongoing migraine in progress, tap to view"))
    }

    /// Resolves a UUID pushed onto a navigation path to its detail view.
    @ContentBuilder
    private func migraineDestination(for migraineID: UUID, onClose: (() -> Void)? = nil) -> some View {
        if let migraine = (migraineManager.visibleMigraines.first { $0.id == migraineID }
                           ?? migraineManager.migraines.first { $0.id == migraineID }) {
            if let onClose {
                MigraineDetailView(migraine: migraine, onClose: onClose)
            } else {
                MigraineDetailView(migraine: migraine)
            }
        } else {
            ContentUnavailableView(
                "Migraine Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected migraine could not be loaded.")
            )
        }
    }

    // MARK: - Helpers

    private var isRegularWidth: Bool {
        hSizeClass == .regular
    }

    private func handleAddTapped() {
        if migraineManager.ongoingMigraine != nil {
            showingOngoingAlert = true
        } else {
            showingEntrySheet = true
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

    return MainView(
        pendingDeepLink: .constant(nil)
    )
    .previewEnvironment()
}

