//
//  MainView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData
import WeatherKit

enum AppTab: String, CaseIterable, Identifiable {
    case insights = "Insights"
    case list = "Migraines"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: Image {
        switch(self) {
        case .insights: return Image(systemName: "lightbulb.max.fill")
        case .list: return Image(systemName: "list.dash")
        case .settings: return Image(systemName: "gear")
        }
    }
    
    var color: Color {
        switch(self) {
        case .insights: return Color.pink
        case .list: return Color.blue
        case .settings: return Color.orange
        }
    }
}

struct MainView: View {
    var returnToAppStage: (AppStage) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var appTab: AppTab = .list // TODO: Change to Insights
    
    var body: some View {
        NavigationStack {
            TabView(selection: $appTab) {
                InsightsView()
                    .tabItem {
                        AppTab.insights.icon
                        Text(AppTab.insights.rawValue)
                    }
                    .tag(AppTab.insights)
                
                MigrainesView()
                    .tabItem {
                        AppTab.list.icon
                        Text(AppTab.list.rawValue)
                    }
                    .tag(AppTab.list)
                
                SettingsView()
                    .tabItem {
                        AppTab.settings.icon
                        Text(AppTab.settings.rawValue)
                    }
                    .tag(AppTab.settings)
            }
            .tint(appTab.color)
            .navigationTitle(appTab.rawValue)
        }
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
    let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
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
        activeHeartRate: 120,
        menstrualPhase: nil
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
        foodsEaten: ["Chocolate"],
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
