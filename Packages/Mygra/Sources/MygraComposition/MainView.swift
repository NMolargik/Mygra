//
//  MainView.swift
//  MygraComposition
//
//  The adaptive four-tab shell: a tab bar on iPhone and a sidebar on iPad/Mac through
//  `.sidebarAdaptable`, with each tab owning its own navigation stack. The tab bar's
//  bottom accessory (iOS 26+) is a persistent status strip — the live ongoing-migraine
//  timer, or a one-tap Log a Migraine action (the header owns the status text). The new-migraine sheet
//  and assistant are presented here, as is the Mygra Plus paywall whenever a gated
//  feature asks for it, and every deep link routes through `AppRouter`.
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
import MygraServices

struct MainView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(InsightModel.self) private var insights
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AttackModeModel.self) private var attackMode

    let session: SessionController

    @State private var navigation = NavigationModel()

    private var router: AppRouter { session.router }

    var body: some View {
        @Bindable var router = router
        @Bindable var paywall = session.paywall
        @Bindable var attackMode = attackMode
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
        // The status strip carries the Log action, so it only belongs on the tabs where
        // logging happens; on Settings it just covers section text.
        .tabViewBottomAccessoryIfAvailable(isEnabled: router.selectedTab != .settings) {
            if #available(iOS 26.0, *) {
                MigraineStatusAccessory(
                    ongoing: migraineData.ongoingMigraine,
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
        .fullScreenCover(isPresented: $attackMode.isPresented) {
            AttackModeView()
        }
        .sheet(item: $paywall.request) { request in
            PaywallView(feature: request.feature)
                .presentationSizing(.page)
        }
        .onChange(of: subscription.isGrandfathered) { _, _ in
            session.showEarlySupporterThanksIfNeeded()
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
            session.showEarlySupporterThanksIfNeeded()
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
            guard #available(iOS 26.0, *), insights.supportsAppleIntelligence else { break }
            if insights.canUseIntelligence {
                navigation.showingAssistant = true
                Task { await insights.startChat() }
            } else {
                session.paywall.present(.assistant)
            }
        case .endOngoing:
            migraineData.endOngoing()
        case .attackMode:
            // Starts an attack when none is active, otherwise opens the one in progress.
            attackMode.enter()
        case .finishLogging(let id):
            attackMode.requestFinish(id)
            navigateToMigraine(id: id)
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
/// opens the detail screen; otherwise just the Log a Migraine action. When the tab bar minimizes on scroll the accessory moves inline next to the
/// selected tab, so the inline placement drops to the essentials.
@available(iOS 26.0, *)
private struct MigraineStatusAccessory: View {
    let ongoing: Migraine?
    let onOpenOngoing: (UUID) -> Void
    let onLog: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isInline: Bool { placement == .inline }

    var body: some View {
        if let ongoing {
            ongoingStrip(ongoing)
        } else {
            logStrip
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

    // MARK: Log

    /// Just the quick action. The dashboard header already says how long it has been,
    /// so the pill never repeats the status.
    private var logStrip: some View {
        Button(action: onLog) {
            Label("Log a Migraine", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.mygraPurple)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("l", modifiers: .command)
        .hoverHighlight()
        .padding(.horizontal, isInline ? Brand.Space.sm : Brand.Space.lg)
        .accessibilityIdentifier("accessoryLogButton")
        .accessibilityLabel(Text("Log a new migraine"))
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
