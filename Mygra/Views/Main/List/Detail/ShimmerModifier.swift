//
//  ShimmerModifier.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.35), Color.clear]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .blendMode(.plusLighter)
                    .mask(content)
                    .offset(x: phase * 180)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
