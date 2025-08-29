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
        VStack {
            Spacer()
            
            Text("All Done!")
                .font(.largeTitle)
                .bold()
            
            HStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.blue)
                Text("Track your migraines")
                    .font(.title3)
            }
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Image(systemName: "lightbulb")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.yellow)
                Text("Get intelligent insights")
                    .font(.title3)
            }
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Image(systemName: "chart.xyaxis.line")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.green)
                Text("Track trends")
                    .font(.title3)
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 16) {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.secondary)
                Text("All of your data syncs automatically wherever you're signed into iCloud!")
                    .font(.title3)
            }
            .padding(.vertical, 8)

            Spacer()
            
            Button("Enter Mygra") {
                finishOnboarding()
            }
            .foregroundStyle(.white)
            .padding()
            .font(.title)
            .bold()
            .frame(width: 200)
            .glassEffect(.regular.interactive().tint(.blue))
        }
    }
}

#Preview {
    OnboardingCompleteView(
        viewModel: OnboardingView.ViewModel(),
        finishOnboarding: {}
    )
}
