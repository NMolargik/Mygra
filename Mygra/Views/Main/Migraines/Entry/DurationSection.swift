//
//  DurationSection.swift
//  Mygra
//
//  Created by Nick Molargik on 9/26/25.
//

import SwiftUI

struct DurationSection: View {
    let titleStart: String
    @Binding var startDate: Date
    @Binding var isOngoing: Bool
    @Binding var endDate: Date
    var showLiveActivityNote: Bool = false

    var body: some View {
        DatePicker(
            titleStart,
            selection: $startDate,
            in: ...Date(),
            displayedComponents: [.date, .hourAndMinute]
        )
        Toggle("Ongoing", isOn: $isOngoing)
        if !isOngoing {
            DatePicker("End", selection: $endDate, in: startDate...Date(), displayedComponents: [.date, .hourAndMinute])
        } else if showLiveActivityNote {
            Text("We'll start a neat little Live Activity to help you track duration!")
                .foregroundStyle(.gray)
        }
    }
}
