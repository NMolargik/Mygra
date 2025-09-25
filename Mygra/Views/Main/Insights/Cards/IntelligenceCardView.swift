//
//  IntelligenceCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct IntelligenceCardView: View {
    let onOpen: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: "apple.intelligence")
                .font(.title)
                .foregroundStyle(
                    AngularGradient(
                        colors: [.orange, .red, .purple, .blue, .purple, .red, .orange, .orange],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Migraine Assistant")
                    .font(.headline)
                Text("Get personalized guidance powered by Apple Intelligence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onOpen) {
                Text("Chat")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel("Open Migraine Assistant")
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
    
#Preview {
    IntelligenceCardView(onOpen: {})
        .padding()
}
