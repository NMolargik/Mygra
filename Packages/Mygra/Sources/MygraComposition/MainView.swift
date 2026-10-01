//
//  MainView.swift
//  MygraComposition
//
//  The four-tab shell (split view on regular widths), the new-migraine sheet, the
//  ongoing-migraine toolbar chip, and deep-link routing through the session's
//  `pendingDeepLink`.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared
import MygraFeatureDashboard
import MygraFeatureCalendar
import MygraFeatureMigraines
import MygraFeatureAssistant
import MygraFeatureSettings

struct MainView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: SessionController

    @State private var navigation = NavigationModel()

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isRegularWidth {
                splitLayout
            } else {
                tabLayout
            }
        }
        .sheet(isPresented: $navigation.showingEntrySheet) {
            MigraineEntryView { migraine in
                if !isRegularWidth { navigation.appTab = .list }
                logNewMigraine(migraine)
            }
            .interactiveDismissDisabled(true)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $navigation.showingAssistant) {
            if #available(iOS 26.0, *) {
                MigraineAssistantView()
            }
        }
        .alert("Ongoing Migraine", isPresented: $navigation.showingOngoingAlert) {
            Button("OK", role: .cancel) {}
            if let ongoing = migraineData.ongoingMigraine {
                Button("View Ongoing") { navigateToMigraine(id: ongoing.id) }
            }
        } message: {
            Text("You already have an ongoing migraine. End it before starting a new one.")
        }
        .onChange(of: navigation.listPath) { _, newValue in
            if newValue.isEmpty { navigation.lastPushedMigraineID = nil }
        }
        .onChange(of: session.pendingDeepLink) { _, newLink in
            handleDeepLink(newLink)
        }
        .onAppear {
            if session.pendingDeepLink != nil {
                handleDeepLink(session.pendingDeepLink)
            }
        }
    }

    // MARK: - Layouts

    private var splitLayout: some View {
        NavigationSplitView {
            NavigationStack {
                MigraineListView()
                    .navigationTitle("")
                    .navigationDestination(for: UUID.self) { id in
                        migraineDestination(for: id)
                    }
            }
        } detail: {
            NavigationStack(path: $navigation.listPath) {
                DashboardView(onNavigateToMigraine: { navigateToMigraine(id: $0) })
                    .navigationTitle("Mygra")
                    .toolbar { addMigraineToolbar }
                    .navigationDestination(for: UUID.self) { id in
                        migraineDestination(for: id, onClose: {
                            if !navigation.listPath.isEmpty { navigation.listPath.removeLast() }
                        })
                    }
            }
        }
    }

    private var tabLayout: some View {
        TabView(selection: $navigation.appTab) {
            NavigationStack {
                DashboardView()
                    .navigationTitle("Mygra")
                    .toolbar { addMigraineToolbar }
            }
            .tint(nil)
            .tabItem {
                AppTab.dashboard.icon()
                Text(AppTab.dashboard.title)
            }
            .tag(AppTab.dashboard)

            NavigationStack(path: $navigation.calendarPath) {
                MigraineCalendarView()
                    .navigationDestination(for: UUID.self) { id in
                        migraineDestination(for: id)
                    }
                    .toolbar { addMigraineToolbar }
            }
            .tint(nil)
            .tabItem {
                AppTab.calendar.icon()
                Text(AppTab.calendar.title)
            }
            .tag(AppTab.calendar)

            NavigationStack(path: $navigation.listPath) {
                MigraineListView()
                    .navigationTitle(AppTab.list.title)
                    .navigationDestination(for: UUID.self) { id in
                        migraineDestination(for: id)
                    }
                    .toolbar { addMigraineToolbar }
            }
            .tint(nil)
            .tabItem {
                AppTab.list.icon()
                Text(AppTab.list.title)
            }
            .tag(AppTab.list)

            NavigationStack {
                SettingsView()
                    .navigationTitle(AppTab.settings.title)
            }
            .tint(nil)
            .tabItem {
                AppTab.settings.icon()
                Text(AppTab.settings.title)
            }
            .tag(AppTab.settings)
        }
        .tint(navigation.appTab.color())
    }

    // MARK: - Toolbar

    /// The top-trailing item on the Dashboard, Calendar, and Migraines pages: a pulsing
    /// ongoing-migraine chip (jumping to that migraine) or the "New Migraine" action.
    @ToolbarContentBuilder
    private var addMigraineToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let ongoing = migraineData.ongoingMigraine {
                Button {
                    navigateToMigraine(id: ongoing.id)
                } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path.ecg")
                                .symbolVariant(.fill)
                                .foregroundStyle(LinearGradient.mygraHorizontal)
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
            } else {
                Button {
                    handleAddTapped()
                } label: {
                    Text("New Migraine")
                        .bold()
                        .foregroundStyle(.mygraBlue)
                }
                .accessibilityIdentifier("addEntryButton")
                .accessibilityLabel(Text("Log a new migraine"))
            }
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func migraineDestination(for id: UUID, onClose: (() -> Void)? = nil) -> some View {
        if let migraine = migraineData.migraine(withID: id) {
            MigraineDetailView(migraine: migraine, onClose: onClose)
        } else {
            ContentUnavailableView(
                "Migraine Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected migraine could not be loaded.")
            )
        }
    }

    private func handleDeepLink(_ link: DeepLink?) {
        guard let link else { return }
        defer { session.pendingDeepLink = nil }

        switch link {
        case .newMigraine: handleAddTapped()
        case .home: navigation.appTab = .dashboard
        case .calendar: navigation.appTab = .calendar
        case .list: navigation.appTab = .list
        case .settings: navigation.appTab = .settings
        case .migraine(let id): navigateToMigraine(id: id)
        case .assistant:
            if #available(iOS 26.0, *) {
                navigation.showingAssistant = true
            }
        case .endOngoing:
            migraineData.endOngoing()
        }
    }

    private func handleAddTapped() {
        if migraineData.ongoingMigraine != nil {
            navigation.showingOngoingAlert = true
        } else {
            navigation.showingEntrySheet = true
        }
    }

    private func logNewMigraine(_ migraine: Migraine) {
        navigation.showingEntrySheet = false
        guard migraineData.log(migraine) else { return }
        navigateToMigraine(id: migraine.id)
    }

    private func navigateToMigraine(id: UUID) {
        if !isRegularWidth {
            navigation.appTab = .list
        }
        guard navigation.lastPushedMigraineID != id else { return }
        navigation.listPath.append(id)
        navigation.lastPushedMigraineID = id
    }
}

// MARK: - Navigation model

@MainActor
@Observable
final class NavigationModel {
    var appTab: AppTab = .dashboard
    var showingEntrySheet = false
    var showingOngoingAlert = false
    var showingAssistant = false
    var listPath = NavigationPath()
    var calendarPath = NavigationPath()
    var lastPushedMigraineID: UUID?
}
#endif
