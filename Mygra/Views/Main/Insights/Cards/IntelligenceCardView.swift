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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.pink)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text("Migraine Assistant")
                    .font(.headline)
                Text("Get personalized guidance powered by Apple Intelligence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onOpen) {
                Text("Open")
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .accessibilityLabel("Open Migraine Assistant")
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
