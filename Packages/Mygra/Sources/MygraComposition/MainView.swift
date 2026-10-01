//
//  MainView.swift
//  MygraComposition
//
//  The adaptive four-tab shell: a tab bar on iPhone and a sidebar on iPad/Mac through
//  `.sidebarAdaptable`, with each tab owning its own navigation stack. The tab bar's
//  bottom accessory (iOS 26+) is a persistent status strip — the live ongoing-migraine
//  timer, or the migraine-free streak with a one-tap Log action. The new-migraine sheet
//  and assistant are presented here, and every deep link routes through `AppRouter`.
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
    @Environment(InsightModel.self) private var insights

    let session: SessionController

    @State private var navigation = NavigationModel()

    private var router: AppRouter { session.router }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage, value: .dashboard) {
                NavigationStack(path: $navigation.dashboardPath) {
                    DashboardView()
                        .navigationTitle("Mygra")
                        .toolbar { newMigraineToolbar }
                        .navigationDestination(for: UUID.self, destination: migraineDestination)
                }
            }

            Tab(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage, value: .calendar) {
                NavigationStack(path: $navigation.calendarPath) {
                    MigraineCalendarView()
                        .toolbar { newMigraineToolbar }
                        .navigationDestination(for: UUID.self, destination: migraineDestination)
                }
            }

            Tab(AppTab.list.title, systemImage: AppTab.list.systemImage, value: .list) {
                NavigationStack(path: $navigation.listPath) {
                    MigraineListView()
                        .navigationTitle(AppTab.list.title)
                        .toolbar { newMigraineToolbar }
                        .navigationDestination(for: UUID.self, destination: migraineDestination)
                }
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                NavigationStack(path: $navigation.settingsPath) {
                    SettingsView()
                        .navigationTitle(AppTab.settings.title)
                        .navigationDestination(for: SettingsDestination.self) { destination in
                            switch destination {
                            case .tags: TagManagementView()
                            case .dashboardStats: DashboardStatsSettingsView()
                            }
                        }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .minimizeTabBarOnScrollIfAvailable()
        .tabViewBottomAccessoryIfAvailable {
            if #available(iOS 26.0, *) {
                MigraineStatusAccessory(
                    ongoing: migraineData.ongoingMigraine,
                    daysSince: MigraineStatistics.streakDays(migraineData.migraines),
                    total: migraineData.migraines.count,
                    onOpenOngoing: { id in navigateToMigraine(id: id) },
                    onLog: handleAddTapped
                )
            }
        }
        .tint(router.selectedTab.color())
        .sheet(isPresented: $navigation.showingEntrySheet) {
            MigraineEntryView { migraine in
                logNewMigraine(migraine)
            }
            .interactiveDismissDisabled(true)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $navigation.showingAssistant) {
            if #available(iOS 26.0, *) {
                MigraineAssistantView()
                    .presentationSizing(.page)
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
        .onChange(of: router.pendingDeepLink) { _, newLink in
            handleDeepLink(newLink)
        }
        .onAppear {
            handleDeepLink(router.pendingDeepLink)
        }
    }

    // MARK: - Toolbar

    /// The top-trailing "New Migraine" action on the Dashboard, Calendar, and Migraines
    /// pages. While a migraine is ongoing the tab-bar accessory takes over, so the
    /// button becomes a shortcut to it.
    @ToolbarContentBuilder
    private var newMigraineToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if let ongoing = migraineData.ongoingMigraine {
                Button {
                    navigateToMigraine(id: ongoing.id)
                } label: {
                    Label("Ongoing Migraine", systemImage: "waveform.path.ecg")
                        .symbolEffect(.pulse, options: .repeating)
                }
                .tint(.mygraPurple)
                .accessibilityIdentifier("ongoingMigraineButton")
                .accessibilityLabel(Text("Ongoing migraine in progress, tap to view"))
            } else {
                Button {
                    handleAddTapped()
                } label: {
                    Label("New Migraine", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("addEntryButton")
                .accessibilityLabel(Text("Log a new migraine"))
            }
        }
    }

    // MARK: - Navigation

    @ContentBuilder
    private func migraineDestination(for id: UUID) -> some View {
        if let migraine = migraineData.migraine(withID: id) {
            MigraineDetailView(migraine: migraine)
                .userActivity(UserActivityType.viewingMigraine) { activity in
                    session.annotateViewingActivity(activity, migraineID: id)
                }
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
        defer { router.pendingDeepLink = nil }

        switch link {
        case .newMigraine: handleAddTapped()
        case .home, .calendar, .list, .settings: break // the router already selected the tab
        case .tags:
            navigation.settingsPath = NavigationPath([SettingsDestination.tags])
        case .migraine(let id): navigateToMigraine(id: id)
        case .assistant:
            if #available(iOS 26.0, *), insights.supportsAppleIntelligence {
                navigation.showingAssistant = true
                Task { await insights.startChat() }
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

    /// Shows a migraine's detail in the Migraines tab, pushing once even when several
    /// sources (toolbar, accessory, deep link) ask for the same record.
    private func navigateToMigraine(id: UUID) {
        router.select(.list)
        guard navigation.listPath.count == 0 || navigation.lastPushedMigraineID != id else { return }
        navigation.listPath = NavigationPath([id])
        navigation.lastPushedMigraineID = id
    }
}

// MARK: - Status accessory

/// The tab-bar bottom accessory. Always present, so it always says something useful:
/// while a migraine is in progress, a pulsing waveform with the live elapsed time that
/// opens the detail screen; otherwise the migraine-free streak with a compact Log
/// action. When the tab bar minimizes on scroll the accessory moves inline next to the
/// selected tab, so the inline placement drops to the essentials.
@available(iOS 26.0, *)
private struct MigraineStatusAccessory: View {
    let ongoing: Migraine?
    let daysSince: Int
    let total: Int
    let onOpenOngoing: (UUID) -> Void
    let onLog: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isInline: Bool { placement == .inline }

    var body: some View {
        if let ongoing {
            ongoingStrip(ongoing)
        } else {
            streakStrip
        }
    }

    // MARK: Ongoing

    private func ongoingStrip(_ migraine: Migraine) -> some View {
        Button {
            onOpenOngoing(migraine.id)
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: Brand.Space.sm) {
                    Image(systemName: "waveform.path.ecg")
                        .symbolVariant(.fill)
                        .foregroundStyle(LinearGradient.mygraHorizontal)
                        .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
                        .accessibilityHidden(true)
                    if !isInline {
                        Text("Ongoing")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(MigraineDates.elapsedString(since: migraine.startDate, now: context.date))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isInline ? .primary : .secondary)
                        .contentTransition(.numericText())
                    if !isInline {
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, isInline ? Brand.Space.sm : Brand.Space.lg)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ongoingMigraineAccessory")
        .accessibilityLabel(Text("Ongoing migraine in progress, tap to view"))
    }

    // MARK: Streak

    private var streakStrip: some View {
        HStack(spacing: Brand.Space.sm) {
            Image(systemName: total == 0 ? "sparkles" : "calendar.badge.checkmark")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.mygraPurple)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: Brand.Space.xs) {
                if total == 0 {
                    Text(isInline ? "Log a migraine" : "No migraines logged yet")
                        .font(.subheadline.weight(.semibold))
                } else if daysSince == 0 {
                    Text("Last migraine today")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text(daysSince, format: .number)
                        .font(isInline ? .subheadline.weight(.bold) : .title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(LinearGradient.mygraHorizontal)
                        .contentTransition(.numericText())
                    Text(daysSince == 1 ? "day migraine-free" : "days migraine-free")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if !isInline {
                Spacer(minLength: Brand.Space.sm)

                Button(action: onLog) {
                    Label("Log", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .glassActionButton(tint: .mygraPurple)
                .controlSize(.small)
                .keyboardShortcut("l", modifiers: .command)
                .hoverHighlight()
                .accessibilityIdentifier("accessoryLogButton")
                .accessibilityLabel(Text("Log a new migraine"))
            }
        }
        .padding(.horizontal, isInline ? Brand.Space.sm : Brand.Space.lg)
        .if(isInline) { $0.contentShape(Rectangle()).onTapGesture(perform: onLog) }
        .accessibilityElement(children: isInline ? .combine : .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: Text {
        if total == 0 { return Text("No migraines logged yet") }
        if daysSince == 0 { return Text("Last migraine today") }
        return Text("\(daysSince) days migraine-free")
    }
}

// MARK: - Navigation model

@MainActor
@Observable
final class NavigationModel {
    var showingEntrySheet = false
    var showingOngoingAlert = false
    var showingAssistant = false
    var dashboardPath = NavigationPath()
    var listPath = NavigationPath()
    var calendarPath = NavigationPath()
    var settingsPath = NavigationPath()
    var lastPushedMigraineID: UUID?
}
#endif
