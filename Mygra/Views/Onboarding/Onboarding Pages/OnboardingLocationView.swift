//
//  OnboardingLocationView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingLocationView: View {
    @Bindable var viewModel: OnboardingView.ViewModel
    var onLocationAuthorized: (LocationManager) -> Void
    
    @State var locationManager = LocationManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text("Location")
                    .font(.largeTitle).bold()
                Text("Mygra uses your location to track local weather conditions and warn you when migraines may be more likely.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Image(systemName: "location.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .foregroundStyle(.red)
                .shadow(radius: 8)
                .padding(.vertical, 8)

            Spacer(minLength: 12)

            Button(action: {
                locationManager.requestAuthorization()
                onLocationAuthorized(locationManager)
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "location.circle.fill")
                        .imageScale(.large)
                    Text("Continue")
                        .font(.title3).bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .adaptiveGlass(tint: .red)
            .padding(.horizontal)
            .shadow(radius: 6, y: 3)
        }
    }
}

#Preview {
    OnboardingLocationView(
        viewModel: OnboardingView.ViewModel(), onLocationAuthorized: { _ in }
    )
}
