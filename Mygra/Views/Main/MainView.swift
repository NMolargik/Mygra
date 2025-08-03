//
//  MainView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var selectedMigraine: Migraine?
    let migrainesViewModel: MigrainesViewModel

    var body: some View {
        TabView {
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "brain.head.profile.fill")
                }
            MigrainesView(viewModel: migrainesViewModel, selectedMigraine: $selectedMigraine)
                .tabItem {
                    Label("Migraines", systemImage: "list.bullet")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
            }
        }
    }
}

#Preview {
    MainView(migrainesViewModel: MigrainesViewModel())
        .modelContainer(for: [User.self, Migraine.self], inMemory: true)
}
