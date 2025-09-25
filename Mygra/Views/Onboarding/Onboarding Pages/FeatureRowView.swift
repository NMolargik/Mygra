//
//  FeatureRowView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/25/25.
//

import SwiftUI

struct FeatureRowView: View {
    let systemImage: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 40, height: 40)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 6, y: 2)
    }
}

#Preview {
    FeatureRowView(systemImage: "brain", title: "Brain", tint: .red)
}
