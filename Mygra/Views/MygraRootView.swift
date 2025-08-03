//
//  MygraRootView.swift
//  Mygra
//
//  Created by Nick Molargik on 7/19/25.
//

import SwiftUI
import SwiftData

enum ViewState {
    case splash
    case onboarding
    case main
}

struct MygraRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var migrainesViewModel = MigrainesViewModel()
    @State private var viewState: ViewState = .main

    var body: some View {
        switch viewState {
        case .splash:
            Text("Splash Screen")
        case .onboarding:
            Text("Onboarding")
        case .main:
            MainView(migrainesViewModel: migrainesViewModel)
                .onAppear {
                    migrainesViewModel.modelContext = modelContext
                }
        }
    }
}

#Preview {
    MygraRootView()
        .modelContainer(for: [User.self, Migraine.self], inMemory: true)
}

