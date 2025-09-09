//
//  StatTileView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation
import SwiftUI

struct StatTileView: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    // A token that changes when the displayed value changes.
    // Default to value string so existing call sites keep working, but callers can override.
    let valueToken: AnyHashable?

    @State private var bounceFlag: Bool = false

    init(title: String, value: String, systemImage: String, color: Color, valueToken: AnyHashable? = nil) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.color = color
        self.valueToken = valueToken
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, options: .repeat(1), value: bounceFlag)
            }
            .font(.subheadline)

            Text(value)
                .font(.title3)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        // Drive bounce when the token changes; default to using the value string if no explicit token provided
        .onChange(of: valueToken ?? AnyHashable(value)) {
            bounceFlag.toggle()
        }
    }
}
