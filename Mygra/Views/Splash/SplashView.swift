//
//  SplashView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct SplashView: View {
    var proceedForward: () -> Void
    var refreshUser: () -> Void
    var viewModel = SplashView.ViewModel()

    var body: some View {
        VStack() {
            Text("Mygra")
                .font(.system(size: 60))
                .bold()
                .opacity(viewModel.titleVisible ? 1 : 0)
                .scaleEffect(viewModel.titleVisible ? 1 : 0.7)
                .animation(.easeOut(duration: 0.6), value: viewModel.titleVisible)
                .padding(.bottom, 5)

            Text("Migraines tracked, insights generated!")
                .font(.title3)
                .opacity(viewModel.subtitleVisible ? 1 : 0)
                .offset(y: viewModel.subtitleVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: viewModel.subtitleVisible)

            Spacer()
            
            Text("Oh! You're new here.")
                .font(.headline)
                .opacity(viewModel.subtitleVisible ? 1 : 0)
                .offset(y: viewModel.subtitleVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.6).delay(1.1), value: viewModel.subtitleVisible)

            Button("Get Started") {
                proceedForward()

            }
            .foregroundStyle(.white)
            .padding()
            .font(.title)
            .bold()
            .frame(width: 200)
            .glassEffect(.regular.interactive().tint(.blue))
            .opacity(viewModel.buttonVisible ? 1 : 0)
            .scaleEffect(viewModel.buttonVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.9), value: viewModel.buttonVisible)
            
            Button("No, I'm not new!") {
                refreshUser()
            }
            .foregroundStyle(.blue)
            .padding()
        }
        .onAppear {
            viewModel.activateAnimation()
        }
        .padding(.top, 80)
    }
}

#Preview {
    SplashView(proceedForward: {}, refreshUser: {})
}
