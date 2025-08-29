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
            UserEditView(
                user: $viewModel.newUser,
                userFormComplete: $viewModel.userFormComplete,
                dismiss: {
                    showingEdit = false
                }
            )
                .transition(.move(edge: .bottom))
            
            if !showingEdit {
                VStack {
                    Spacer()
                    
                    Text("You")
                        .font(.largeTitle)
                        .bold()
                    
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .foregroundStyle(.orange)
                        .shadow(radius: 5)
                    
                    Text("Mygra requires some information about you to best tailor the experience and draw insights from your migraines.\n\nAgain, all of your data will be stored on your device or encrypted in iCloud.")
                        .padding()
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                            .font(.title)
                            .foregroundColor(.orange)
                            .shadow(radius: 2)
                        SparkleText(text: "Swipe Up To Continue")
                    }
                    .padding()
                }
                .background(.white)
                .zIndex(1)
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
                .padding(.bottom, 20)
            }
        }
        .animation(.spring(), value: showingEdit)
    }
}

#Preview {
    OnboardingUserView(viewModel: OnboardingView.ViewModel())
}
