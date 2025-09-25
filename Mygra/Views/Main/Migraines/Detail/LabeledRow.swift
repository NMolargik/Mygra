//
//  LabeledRow.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct LabeledRow<Value: View>: View {
    let title: String
    let valueView: Value

    init(_ title: String, @ViewBuilder value: () -> Value) {
        self.title = title
        self.valueView = value()
    }

    init(_ title: String, value: String) where Value == Text {
        self.title = title
        self.valueView = Text(value)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            valueView
        }
    }
}

#Preview {
    LabeledRow("Labeled Row", value: "")
}
