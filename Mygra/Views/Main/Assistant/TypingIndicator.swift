//
//  TypingIndicator.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct TypingIndicator: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(opacity(for: i))
            }
        }
        .accessibilityLabel("Assistant is typing")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        let base = (Double(index) * 0.3)
        let t = (sin((phase * 2 * .pi) + base) + 1) / 2
        return 0.35 + t * 0.65
    }
}

#Preview {
    TypingIndicator()
}
