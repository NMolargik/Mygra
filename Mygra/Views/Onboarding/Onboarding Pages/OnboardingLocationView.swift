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
        VStack {
            Spacer()
            
            Text("Location")
                .font(.largeTitle)
                .bold()
            
            Image(systemName: "location.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .foregroundStyle(.red)
                .shadow(radius: 5)
            
            Text("Mygra uses your location to track local weather conditions and warn you when migraines may be more likely.")
                .padding()
            
            Spacer()
            
            Button("Authorize") {
                locationManager.requestAuthorization()
                onLocationAuthorized(locationManager)
            }
            .foregroundStyle(.white)
            .padding()
            .font(.title)
            .bold()
            .frame(width: 200)
            .glassEffect(.regular.interactive().tint(.red))
        }
    }
}

#Preview {
    OnboardingLocationView(
        viewModel: OnboardingView.ViewModel(), onLocationAuthorized: { _ in }
    )
}
