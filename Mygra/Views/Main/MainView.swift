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
    @State private var appTab: AppTab = .list // TODO: Change to Insights
    
    @State private var showingEntrySheet: Bool = false

    // Navigation path for the List tab
    @State private var listPath = NavigationPath()
    // Track the last pushed migraine id explicitly (avoid introspecting NavigationPath)
    @State private var lastPushedMigraineID: UUID? = nil
    // A ticking date to refresh the duration display while ongoing
    @State private var now: Date = Date()
    // Drive SF Symbols draw-on/draw-off animation
    @State private var drawOn: Bool = false
    @State private var drawOff: Bool = false
    
    var body: some View {
        TabView(selection: $appTab) {
            NavigationStack {
                InsightsView(
                    showingEntrySheet: $showingEntrySheet
                )
                    .navigationTitle(AppTab.insights.rawValue)
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
                    // Destination for programmatic navigation by Migraine ID
                    .navigationDestination(for: UUID.self) { migraineID in
                        // Attempt to find the migraine by id in the manager
                        if let migraine = (migraineManager.visibleMigraines.first { $0.id == migraineID }
                                           ?? migraineManager.migraines.first { $0.id == migraineID }) {
                            MigraineDetailView(migraine: migraine)
                                .onAppear {
                                    // TODO: Kick off migraine insight creation!!!!!
                                }
                        } else {
                            // Fallback view if not found
                            ContentUnavailableView(
                                "Migraine Not Found",
                                systemImage: "exclamationmark.triangle",
                                description: Text("The selected migraine could not be loaded.")
                            )
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
        .tabViewBottomAccessory {
            if let ongoing = migraineManager.ongoingMigraine {
                Button {
                    // Navigate to the ongoing migraine detail (only once)
                    appTab = .list
                    // If already showing this migraine at the top of the stack, do nothing
                    if lastPushedMigraineID == ongoing.id {
                        return
                    }
                    listPath.append(ongoing.id)
                    lastPushedMigraineID = ongoing.id
                } label: {
                    HStack(spacing: 8) {
                        // ECG symbol with draw-on/draw-off animation
                        Image(systemName: "waveform.path.ecg")
                            .symbolVariant(.fill)
                            .foregroundStyle(.pink)
                            // Use availability to prefer a draw-like effect if the SDK exposes it,
                            // otherwise fall back to a pulse that’s driven by drawOn/drawOff.
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
                // Drive periodic updates so duration ticks while ongoing and retrigger the animation
                .onReceive(timer) { tick in
                    self.now = tick
                    // Alternate reveal/hide phases by toggling both flags.
                    // If you prefer a staggered cadence, toggle drawOn first and drawOff after a delay.
                    withAnimation(.easeInOut(duration: 0.8)) {
                        self.drawOn.toggle()
                        self.drawOff.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEntrySheet) {
            MigraineEntryView(onMigraineSaved: { migraine in
                // Dismiss the sheet
                showingEntrySheet = false
                // Switch to the List tab
                appTab = .list
                // Push the detail for the newly created migraine
                // Avoid double-pushing if already on top
                if lastPushedMigraineID == migraine.id {
                    return
                }
                listPath.append(migraine.id)
                lastPushedMigraineID = migraine.id
            })
                .interactiveDismissDisabled(true)
                .presentationDetents([.large])
        }
        // Optional: keep lastPushedMigraineID roughly in sync with path emptiness
        .onChange(of: listPath) { _, newValue in
            if newValue.count == 0 {
                lastPushedMigraineID = nil
            }
        }
    }
    
    // A 1-second timer publisher to keep the duration label fresh and drive drawOn toggling
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        // If you want a faster “heartbeat”, reduce the interval (e.g., 0.6 for ~100 BPM)
        Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    }
    
    // Formats elapsed time since start into H:MM:SS or M:SS if under 1 hour
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
}

// MARK: - DrawOnOffEffect: wraps symbolEffect availability differences
private struct DrawOnOffEffect: ViewModifier {
    let drawOn: Bool
    let drawOff: Bool
    
    func body(content: Content) -> some View {
        // Try to use the “draw” effect if the SDK provides it under the expected names.
        // Because your current toolchain reports missing members, keep the code compiling
        // by using a conditional compilation path with a safe fallback.
        #if compiler(>=6.0)
        // Future-facing: if “draw/reveal/hide” exist, prefer them.
        // Replace the below with the exact members once they’re available in your SDK:
        //   .symbolEffect(.draw, options: .reveal, value: drawOn)
        //   .symbolEffect(.draw, options: .hide, value: drawOff)
        content
            // Temporary fallback under this branch as well, to keep builds green until the API lands.
            .symbolEffect(.pulse, options: .repeating, value: drawOn)
        #else
        // Current stable fallback (iOS 17/18 era): repeatable pulse driven by drawOn.
        content
            .symbolEffect(.pulse, options: .repeating, value: drawOn)
        #endif
    }
}

#Preview {
    let container: ModelContainer
    do {
        // Mirror the app schema but use an in-memory store for previews
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
    
    // Insert sample data into the in-memory preview context
    let now = Date()
    let cal = Calendar.current
    
    // Helper: make dates
    let twoHoursAgo = cal.date(byAdding: .hour, value: -2, to: now)!
    let yesterdayStart = cal.date(byAdding: .hour, value: -20, to: now)! // roughly yesterday
    let yesterdayEnd = cal.date(byAdding: .hour, value: -18, to: now)!
    let lastWeekStart = cal.date(byAdding: .day, value: -7, to: now)!
    let lastWeekEnd = cal.date(byAdding: .day, value: -7, to: cal.date(byAdding: .hour, value: 2, to: now)!)!
    
    // Sample weather snapshots
    let wx1 = WeatherData(
        barometricPressureHpa: 1008,
        temperatureCelsius: 29,
        humidityPercent: 70,
        condition: .clear
    )
    let wx2 = WeatherData(
        barometricPressureHpa: 1016,
        temperatureCelsius: 22,
        humidityPercent: 45,
        condition: .clear
    )
    let wx3 = WeatherData(
        barometricPressureHpa: 999,
        temperatureCelsius: 31,
        humidityPercent: 80,
        condition: .thunderstorms
    )
    
    // Sample health snapshots
    let h1 = HealthData(
        waterLiters: 1.2,
        sleepHours: 6.0,
        energyKilocalories: 2100,
        caffeineMg: 180,
        stepCount: 4500,
        restingHeartRate: 62,
        activeHeartRate: 110,
        menstrualPhase: nil
    )
    let h2 = HealthData(
        waterLiters: 2.0,
        sleepHours: 7.5,
        energyKilocalories: 2300,
        caffeineMg: 80,
        stepCount: 8200,
        restingHeartRate: 58,
        activeHeartRate: 102,
        menstrualPhase: nil
    )
    let h3 = HealthData(
        waterLiters: 0.8,
        sleepHours: 5.0,
        energyKilocalories: 2000,
        caffeineMg: 250,
        stepCount: 3000,
        restingHeartRate: 65,
        activeHeartRate: 120
    )
    
    // Create a few migraines
    _ = migraineManager.create(
        startDate: twoHoursAgo,
        endDate: now, // ended recently
        painLevel: 7,
        stressLevel: 6,
        pinned: true,
        note: "Throbbing pain after long screen time.",
        insight: "Likely triggered by screen flicker and dehydration.",
        triggers: [.screenTimeFlicker, .dehydration],
        foodsEaten: ["Coffee", "Granola bar"],
        weather: wx1,
        health: h1
    )
    
    _ = migraineManager.create(
        startDate: yesterdayStart,
        endDate: yesterdayEnd,
        painLevel: 3,
        stressLevel: 4,
        pinned: false,
        note: "Mild headache, improved after water and rest.",
        insight: "Hydration and lower stress correlated with improvement.",
        triggers: [.stress],
        foodsEaten: ["Salad", "Tea"],
        weather: wx2,
        health: h2
    )
    
    _ = migraineManager.create(
        startDate: lastWeekStart,
        endDate: lastWeekEnd,
        painLevel: 9,
        stressLevel: 8,
        pinned: false,
        note: "Severe migraine during thunderstorm.",
        insight: "Barometric pressure drop and high humidity likely factors.",
        triggers: [.barometricPressureChange, .highHumidity, .stormsWind],
        weather: wx3,
        health: h3
    )
    
    return MainView(
        returnToAppStage: { _ in }
    )
    .modelContainer(container)
    .environment(previewUserManager)
    .environment(migraineManager) // Preview supplies the manager
    .environment(previewWeatherManager)
    .environment(previewHealthManager)
    .environment(previewLocationManager)
    .environment(previewNotificationManager)
}
