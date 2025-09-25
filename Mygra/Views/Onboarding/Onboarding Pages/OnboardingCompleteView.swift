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
                FeatureRowView(
                    systemImage: "lightbulb.max.fill",
                    title: "Get intelligent insights.",
                    tint: .yellow
                )
                FeatureRowView(
                    systemImage: "chart.xyaxis.line",
                    title: "View trends and likely migraine causes.",
                    tint: .green
                )
                FeatureRowView(
                    systemImage: "icloud.fill",
                    title: "All of your data syncs automatically wherever you're signed into iCloud!",
                    tint: .secondary
                )
            }
            .padding(.horizontal)

            Spacer(minLength: 12)

            // Primary action
            Button(action: finishOnboarding) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.large)
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
            .shadow(radius: 8, y: 3)

            Spacer(minLength: 8)
        }
    }
}

#Preview {
    OnboardingCompleteView(
        viewModel: OnboardingView.ViewModel(),
        finishOnboarding: {}
    )
}
