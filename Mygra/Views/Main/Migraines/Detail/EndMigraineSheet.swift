//
//  EndMigraineSheet.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import SwiftUI

struct EndMigraineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let startDate: Date
    let initialEndDate: Date
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void

    @State private var endDate: Date

    init(startDate: Date, initialEndDate: Date, onConfirm: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        self.startDate = startDate
        self.initialEndDate = initialEndDate
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _endDate = State(initialValue: initialEndDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...Date().addingTimeInterval(365*24*3600),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("Choose when this migraine ended. The end time must be after the start time.")
                }
            }
            .navigationTitle("End Migraine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .tint(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onConfirm(endDate)
                    }
                    .bold()
                    .tint(.mygraBlue)
                }
            }
        }
    }
}

#Preview("Sample EndMigraineSheet") {
    EndMigraineSheet(
        startDate: Date().addingTimeInterval(-3600),
        initialEndDate: Date(),
        onConfirm: { _ in },
        onCancel: {}
    )
}

