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
    @GestureState private var dragOffset: CGFloat = 0
    
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
                        .foregroundStyle(.orange)
                        .shadow(radius: 8)
                        .padding(.vertical, 8)
                    
                    Spacer(minLength: 12)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .shadow(radius: 2)
                        SparkleText(text: "Swipe Up To Continue")
                            .font(.headline)
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.height < 0 { state = value.translation.height }
                        }
                        .onEnded { value in
                            if value.translation.height < -200 && !showingEdit {
                                showingEdit = true
                            }
                        }
                )
            }
        }
        .animation(.spring(), value: showingEdit)
        .navigationTitle("User Details")
    }
}

#Preview {
    OnboardingUserView(viewModel: OnboardingView.ViewModel())
}
