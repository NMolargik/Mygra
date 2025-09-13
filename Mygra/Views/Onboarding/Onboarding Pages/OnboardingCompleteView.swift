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
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack(spacing: 16) {
                Image(systemName: "brain.head.profile.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.blue)
                Text("Track your migraines.")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Image(systemName: "lightbulb.max.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.yellow)
                Text("Get intelligent insights.")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Image(systemName: "chart.xyaxis.line")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.green)
                Text("View trends and likely migraine causes.")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            
            HStack(spacing: 16) {
                Image(systemName: "icloud.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.secondary)
                Text("All of your data syncs automatically wherever you're signed into iCloud!")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, alignment: .center)
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
            .glassEffect(.regular.interactive().tint(.red))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal)
    }
}

#Preview {
    OnboardingCompleteView(
        viewModel: OnboardingView.ViewModel(),
        finishOnboarding: {}
    )
}
