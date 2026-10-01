//
//  DurationSection.swift
//  MygraFeatureShared
//
//  Start / ongoing / end controls shared by the entry form and the modify sheet.
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

public struct DurationSection: View {
    let startTitle: LocalizedStringKey
    @Binding var startDate: Date
    @Binding var isOngoing: Bool
    @Binding var endDate: Date
    let showLiveActivityNote: Bool

    public init(
        startTitle: LocalizedStringKey,
        startDate: Binding<Date>,
        isOngoing: Binding<Bool>,
        endDate: Binding<Date>,
        showLiveActivityNote: Bool = false
    ) {
        self.startTitle = startTitle
        _startDate = startDate
        _isOngoing = isOngoing
        _endDate = endDate
        self.showLiveActivityNote = showLiveActivityNote
    }

    public var body: some View {
        DatePicker(startTitle, selection: $startDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            .tint(.mygraPurple)

        Toggle("Ongoing", isOn: $isOngoing)

        if !isOngoing {
            DatePicker("Ended", selection: $endDate, in: startDate...Date(), displayedComponents: [.date, .hourAndMinute])
                .tint(.mygraPurple)
        } else if showLiveActivityNote {
            Text("We'll start a neat little Live Activity to help you track duration!")
                .foregroundStyle(.gray)
        }
    }
}
#endif
