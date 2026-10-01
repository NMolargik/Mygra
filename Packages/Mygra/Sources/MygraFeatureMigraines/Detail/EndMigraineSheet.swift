//
//  EndMigraineSheet.swift
//  MygraFeatureMigraines
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

struct EndMigraineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let startDate: Date
    let onConfirm: (Date) -> Void

    @State private var endDate: Date

    init(startDate: Date, initialEndDate: Date, onConfirm: @escaping (Date) -> Void) {
        self.startDate = startDate
        self.onConfirm = onConfirm
        _endDate = State(initialValue: initialEndDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...Date().addingTimeInterval(365 * 24 * 3600),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .tint(.mygraPurple)
                } footer: {
                    Text("Choose when this migraine ended. The end time must be after the start time.")
                }
            }
            .navigationTitle("End Migraine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("End") { onConfirm(endDate) }
                        .bold()
                        .tint(.mygraPurple)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

#Preview {
    EndMigraineSheet(startDate: Date().addingTimeInterval(-3600), initialEndDate: Date(), onConfirm: { _ in })
}
#endif
