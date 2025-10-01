//
//  TypingIndicator.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct TypingIndicator: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let duration: TimeInterval = 1.5
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Normalize to 0...1 repeating phase
            let phase = CGFloat((t / duration).truncatingRemainder(dividingBy: 1))

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    let progress = wave(phase: phase, index: i)
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(0.95 + 0.20 * progress)
                        .opacity(0.6 + 0.4 * progress)
                }
            }
            .accessibilityLabel("Assistant is typing")
        }
    }
    
    private func wave(phase: CGFloat, index: Int) -> CGFloat {
        let offset = Double(index) * (2 * .pi / 3) // 0°, 120°, 240°
        let t = sin(Double(phase) * 2 * .pi - offset)
        return CGFloat((t + 1) / 2)
    }
}

#Preview {
    TypingIndicator()
}
