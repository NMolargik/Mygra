//
//  OnboardingUserView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingUserView: View {
    @Bindable var viewModel: OnboardingView.ViewModel
    
    @State private var showingEdit = false
    
    var body: some View {
        ZStack {
            Group {
                Form {
                    UserEditView(
                        user: $viewModel.newUser,
                        userFormComplete: $viewModel.userFormComplete,
                        dismiss: {
                            showingEdit = false
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
                .navigationTitle("User")
                .opacity(showingEdit ? 1 : 0)
                .allowsHitTesting(showingEdit)
                .accessibilityHidden(!showingEdit)
            }
            
            if !showingEdit {
                VStack(spacing: 20) {
                    Spacer(minLength: 12)
                    
                    VStack(spacing: 8) {
                        Text("You")
                            .font(.largeTitle).bold()
                            .foregroundStyle(.white)
                            .shadow(radius: 5, x: 1, y: -1)
                        
                        Text("Mygra requires some information about you to best tailor the experience and draw insights from your migraines. Again, all of your data will be stored on your device or encrypted in iCloud.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .foregroundStyle(LinearGradient(colors: [.orange, .orange.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))                        .shadow(radius: 8)
                        .padding(.vertical, 8)
                    
                    Spacer(minLength: 12)
                    
                    Button(action: {
                        showingEdit = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .imageScale(.large)
                            Text("Continue")
                                .font(.title3).bold()
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .adaptiveGlass(tint: .mygraPurple)
                    .shadow(radius: 6, y: 3)
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.spring(), value: showingEdit)
        .navigationTitle("User Details")
    }
}

#Preview {
    OnboardingUserView(viewModel: OnboardingView.ViewModel())
}
