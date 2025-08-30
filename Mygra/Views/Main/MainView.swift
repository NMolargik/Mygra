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
    var returnToAppStage: (AppStage) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var appTab: AppTab = .insights // iPhone / compact-only
    
    @State private var showingEntrySheet: Bool = false
    @State private var showingSettingsSheet: Bool = false
    @State private var showingOngoingAlert: Bool = false

    @State private var listPath = NavigationPath()
    @State private var lastPushedMigraineID: UUID? = nil
    @State private var now: Date = Date()
    @State private var drawOn: Bool = false
    @State private var drawOff: Bool = false
    
    var body: some View {
        Group {
            if isRegularWidth {
                NavigationSplitView {
                    NavigationStack {
                        MigraineListView(showingEntrySheet: $showingEntrySheet)
                            .navigationTitle("")
                            .toolbar {
                                if migraineManager.ongoingMigraine == nil {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button {
                                            handleAddTapped()
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "plus")
                                            }
                                            .foregroundStyle(.blue)
                                        }
                                        .accessibilityIdentifier("addEntryButton")
                                        .tint(.blue)
                                    }
                                }
                            }
                    }
                } detail: {
                    NavigationStack(path: $listPath) {
                        InsightsView(showingEntrySheet: $showingEntrySheet)
                            .navigationTitle(AppTab.insights.rawValue)
                            .toolbar {
                                ToolbarItemGroup(placement: .topBarTrailing) {
                                    Button {
                                        showingSettingsSheet = true
                                    } label: {
                                        Image(systemName: "gearshape")
                                    }
                                    .accessibilityLabel("Settings")
                                    .tint(.orange)
                                }
                            }
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
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsView()
                        .presentationDetents([.large, .medium])
                }
                .tabViewBottomAccessory { ongoingAccessory }
                .sheet(isPresented: $showingEntrySheet) {
                    MigraineEntryView(onMigraineSaved: { migraine in
                        showingEntrySheet = false
                        if lastPushedMigraineID != migraine.id {
                            listPath.append(migraine.id)
                            lastPushedMigraineID = migraine.id
                        }
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
                        InsightsView(
                            showingEntrySheet: $showingEntrySheet
                        )
                        .navigationTitle("Mygra")
                        .toolbar {
                            if migraineManager.ongoingMigraine == nil {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        handleAddTapped()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                            Text("New Migraine")
                                                .bold()
                                        }
                                        .foregroundStyle(.blue)
                                    }
                                    .accessibilityIdentifier("addEntryButton")
                                }
                            }
                        }
                    }
                    .tabItem {
                        AppTab.insights.icon(selectedTab: appTab)
                        Text(AppTab.insights.rawValue)
                    }
                    .tag(AppTab.insights)
                    
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
                        .toolbar {
                            if migraineManager.ongoingMigraine == nil {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        handleAddTapped()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                            Text("Add")
                                                .bold()

                                        }
                                        .foregroundStyle(.blue)
                                    }
                                    .accessibilityIdentifier("addEntryButton")
                                }
                            }
                        }
                    }
                    .tabItem {
                        AppTab.list.icon(selectedTab: appTab)
                        Text(AppTab.list.rawValue)
                    }
                    .tag(AppTab.list)
                    
                    NavigationStack {
                        SettingsView()
                            .navigationTitle(AppTab.settings.rawValue)
                    }
                    .tabItem {
                        AppTab.settings.icon(selectedTab: appTab)
                        Text(AppTab.settings.rawValue)
                    }
                    .tag(AppTab.settings)
                }
                .tint(appTab.color)
                .tabViewBottomAccessory { ongoingAccessory }
                .sheet(isPresented: $showingEntrySheet) {
                    MigraineEntryView(onMigraineSaved: { migraine in
                        showingEntrySheet = false
                        appTab = .list
                        if lastPushedMigraineID != migraine.id {
                            listPath.append(migraine.id)
                            lastPushedMigraineID = migraine.id
                        }
                    })
                    .interactiveDismissDisabled(true)
                    .presentationDetents([.large])
                }
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsView()
                        .presentationDetents([.large, .medium])
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
        // Deep link handling
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(url: URL) {
        guard url.scheme?.lowercased() == "mygra" else { return }
        // Expecting mygra://migraine/<UUID>?action=end (action is optional)
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2, pathComponents[0].lowercased() == "migraine" else { return }
        let idString = pathComponents[1]
        guard let uuid = UUID(uuidString: idString) else { return }
        let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "action" })?.value

        // Navigate to detail
        if !isRegularWidth {
            appTab = .list
        }
        if lastPushedMigraineID != uuid {
            listPath.append(uuid)
            lastPushedMigraineID = uuid
        }

        // If action=end, end the migraine now
        if action?.lowercased() == "end" {
            if let migraine = (migraineManager.visibleMigraines.first { $0.id == uuid }
                               ?? migraineManager.migraines.first { $0.id == uuid }) {
                if migraine.endDate == nil {
                    migraineManager.update(migraine) { m in
                        m.endDate = Date()
                    }
                    // Live Activity end will be triggered by MigraineManager.update
                }
            } else {
                // No-op if not found; UI will show "not found" destination
            }
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
                    Image(systemName: "waveform.path.ecg")
                        .symbolVariant(.fill)
                        .foregroundStyle(.pink)
                        .modifier(DrawOnOffEffect(drawOn: drawOn, drawOff: drawOff))
                    
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
                self.now = tick
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.drawOn.toggle()
                    self.drawOff.toggle()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isRegularWidth: Bool {
        hSizeClass == .regular
    }
    
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
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
}

// MARK: - DrawOnOffEffect
private struct DrawOnOffEffect: ViewModifier {
    let drawOn: Bool
    let drawOff: Bool
    
    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        content
            .symbolEffect(.pulse, options: .repeating, value: drawOn)
        #else
        content
            .symbolEffect(.pulse, options: .repeating, value: drawOn)
        #endif
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: User.self, Migraine.self, WeatherData.self, HealthData.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let previewUserManager = UserManager(context: container.mainContext)
    let migraineManager = MigraineManager(context: container.mainContext)
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()
    let previewNotificationManager = NotificationManager()
    let previewLocationManager = LocationManager()
    
    let now = Date()
    let twoHoursAgo = Calendar.current.date(byAdding: .hour, value: -2, to: now)!

    _ = migraineManager.create(
        startDate: twoHoursAgo,
        endDate: nil,
        painLevel: 7,
        stressLevel: 6,
        pinned: true,
        note: "Ongoing for preview",
        insight: nil,
        triggers: [],
        foodsEaten: []
    )
    
    return MainView(
        returnToAppStage: { _ in }
    )
    .modelContainer(container)
    .environment(previewUserManager)
    .environment(migraineManager)
    .environment(previewWeatherManager)
    .environment(previewHealthManager)
    .environment(previewLocationManager)
    .environment(previewNotificationManager)
}

