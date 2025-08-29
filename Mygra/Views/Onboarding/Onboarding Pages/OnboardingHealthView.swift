//
//  OnboardingHealthView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingHealthView: View {
    @Bindable var viewModel: OnboardingView.ViewModel
    @Environment(HealthManager.self) var healthManager: HealthManager
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("Apple Health")
                .font(.largeTitle)
                .bold()
            
            Image("appleHealth")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .shadow(radius: 5)
            
            Text("Mygra connects directly to Apple Health to read and write critical health data, allowing us to track your migraines.\nAll data stays secure on your device, or encrypted in iCloud.\n\nPlease authorize all options!")
                .padding()
            
            Spacer()
            
            Button("Authorize") {
                Task {
                    await healthManager.requestAuthorization()
                }
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
    OnboardingHealthView(viewModel: OnboardingView.ViewModel())
}
