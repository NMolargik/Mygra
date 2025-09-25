//
//  OnboardingCompleteView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Bindable var viewModel: OnboardingView.ViewModel
    var finishOnboarding: () -> Void
    
    @State private var shownRows: [Bool] = [false, false, false, false]
    @State private var showButton: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text("All Done!")
                    .font(.largeTitle).bold()
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("You’re set. Here’s what Mygra can do for you:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Feature cards
            VStack(spacing: 14) {
                FeatureRowView(
                    systemImage: "brain.head.profile.fill",
                    title: "Track your migraines.",
                    tint: .blue
                )
                .opacity(shownRows[0] ? 1 : 0)
                .offset(x: shownRows[0] ? 0 : -32)
                .animation(.spring(response: 1.2, dampingFraction: 0.85), value: shownRows[0])
                .symbolEffect(.bounce, value: shownRows[0])

                FeatureRowView(
                    systemImage: "lightbulb.max.fill",
                    title: "Get intelligent insights.",
                    tint: .yellow
                )
                .opacity(shownRows[1] ? 1 : 0)
                .offset(x: shownRows[1] ? 0 : 32)
                .animation(.spring(response: 1.2, dampingFraction: 0.85), value: shownRows[1])
                .symbolEffect(.bounce, value: shownRows[1])

                FeatureRowView(
                    systemImage: "chart.xyaxis.line",
                    title: "View trends and likely migraine causes.",
                    tint: .green
                )
                .opacity(shownRows[2] ? 1 : 0)
                .offset(x: shownRows[2] ? 0 : -32)
                .animation(.spring(response: 1.2, dampingFraction: 0.85), value: shownRows[2])
                .symbolEffect(.bounce, value: shownRows[2])

                FeatureRowView(
                    systemImage: "icloud.fill",
                    title: "All of your data syncs automatically wherever you're signed into iCloud!",
                    tint: .secondary
                )
                .opacity(shownRows[3] ? 1 : 0)
                .offset(x: shownRows[3] ? 0 : 32)
                .animation(.spring(response: 1.2, dampingFraction: 0.85), value: shownRows[3])
                .symbolEffect(.bounce, value: shownRows[3])
            }
            .padding(.horizontal)

            Spacer(minLength: 12)

            // Primary action
            Button(action: finishOnboarding) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.large)
                        .symbolEffect(.bounce, value: showButton)
                    Text("Enter Mygra")
                        .font(.title3).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .adaptiveGlass(tint: .red)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 12)
            .animation(.spring(response: 1.2, dampingFraction: 0.85), value: showButton)
            .shadow(radius: 8, y: 3)

            Spacer(minLength: 8)
        }
        .task {
            for i in 0..<shownRows.count {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.spring(response: 1.2, dampingFraction: 0.85)) {
                    shownRows[i] = true
                }
            }
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation(.spring(response: 1.2, dampingFraction: 0.85)) {
                showButton = true
            }
        }
    }
}

#Preview {
    OnboardingCompleteView(
        viewModel: OnboardingView.ViewModel(),
        finishOnboarding: {}
    )
}
