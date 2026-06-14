//
//  InsightCard.swift
//  Mygra
//
//  The standard content card used across the app: a material surface with a
//  restrained single-accent gradient wash, a hairline border, and a soft
//  shadow. Keeps color usage disciplined and HIG-aligned.
//

import SwiftUI

struct InsightCard<Content: View>: View {
    let title: String?
    let systemImage: String?
    let accent: Color
    let content: Content

    init(
        title: String? = nil,
        systemImage: String? = nil,
        accent: Color = .mygraBlue,
        @ContentBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack {
                    if let systemImage {
                        Label(title, systemImage: systemImage)
                            .font(.headline.weight(.semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(accent, .primary)
                    } else {
                        Text(title)
                            .font(.headline.weight(.semibold))
                    }
                    Spacer(minLength: 0)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            InsightCard(title: "Today", systemImage: "sun.max", accent: .mygraBlue) {
                Text("No migraine today.")
                    .foregroundStyle(.secondary)
            }
            InsightCard(title: "Triggers", systemImage: "bolt", accent: .mygraPurple) {
                Text("Stress, caffeine, sleep")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
