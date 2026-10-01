//
//  DashboardStatsSettingsView.swift
//  MygraFeatureSettings
//
//  Which Health tiles the Today card shows, and in what order. Visibility toggles
//  persist per stat; the order persists as one JSON preference (`DashboardStat`
//  owns the rules so the Today card and this list agree).
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct DashboardStatsSettingsView: View {
    @AppStorage(AppStorageKeys.dashboardStatOrder) private var orderData: Data?

    @State private var order: [DashboardStat] = DashboardStat.defaultOrder

    public init() {}

    public var body: some View {
        List {
            Section {
                let rows = ForEach(order) { stat in
                    DashboardStatToggle(stat: stat)
                }
                .onMove(perform: move)

                // iOS 27 adds drag-anywhere reordering; earlier releases reorder through Edit mode.
                if #available(iOS 27.0, *) {
                    rows.reorderable()
                } else {
                    rows
                }
            } header: {
                Text("Today Card")
            } footer: {
                Text("Switch stats on or off and drag to arrange them. The Today card follows this order.")
            }

            Section {
                Button {
                    Haptics.lightImpact()
                    withAnimation { order = DashboardStat.defaultOrder }
                    persist()
                } label: {
                    Label("Reset Order", systemImage: "arrow.counterclockwise")
                }
                .disabled(order == DashboardStat.defaultOrder)
            }
        }
        .navigationTitle("Dashboard Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .onAppear { order = DashboardStat.order(from: orderData) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        Haptics.lightImpact()
        order.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        orderData = DashboardStat.encodeOrder(order)
    }
}

/// One stat's visibility toggle with its tinted icon.
struct DashboardStatToggle: View {
    let stat: DashboardStat
    @AppStorage private var isVisible: Bool

    init(stat: DashboardStat) {
        self.stat = stat
        _isVisible = AppStorage(wrappedValue: stat.defaultVisibility, stat.storageKey)
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isVisible },
            set: { newValue in
                isVisible = newValue
                Haptics.lightImpact()
            }
        )) {
            Label(stat.displayName, systemImage: stat.systemImage)
                .labelStyle(.settingsIcon(stat.color))
        }
        .tint(stat.color)
    }
}

#Preview {
    NavigationStack {
        DashboardStatsSettingsView()
    }
}
#endif
