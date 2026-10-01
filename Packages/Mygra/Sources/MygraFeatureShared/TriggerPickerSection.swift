//
//  TriggerPickerSection.swift
//  MygraFeatureShared
//
//  The grouped, searchable multi-select trigger list shared by the entry form, the
//  modify sheet, and the list filter.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct TriggerPickerSection: View {
    @Binding var selection: Set<MigraineTrigger>
    let searchText: String
    let tint: Color

    public init(selection: Binding<Set<MigraineTrigger>>, searchText: String = "", tint: Color = .mygraBlue) {
        _selection = selection
        self.searchText = searchText
        self.tint = tint
    }

    public var body: some View {
        ForEach(MigraineTrigger.Group.allCases, id: \.self) { group in
            let items = MigraineTrigger.triggers(in: group, matching: searchText)
            if !items.isEmpty {
                DisclosureGroup(group.displayName) {
                    ForEach(items, id: \.self) { trigger in
                        Button {
                            Haptics.lightImpact()
                            toggle(trigger)
                        } label: {
                            HStack {
                                Text(trigger.displayName)
                                Spacer()
                                Image(systemName: selection.contains(trigger) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(tint)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func toggle(_ trigger: MigraineTrigger) {
        if selection.contains(trigger) {
            selection.remove(trigger)
        } else {
            selection.insert(trigger)
        }
    }
}

/// A search field with an inline clear button.
public struct SearchField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String

    public init(_ placeholder: LocalizedStringKey, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    public var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    Haptics.lightImpact()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
    }
}

#if DEBUG
#Preview {
    struct PreviewView: View {
        @State var selection: Set<MigraineTrigger> = [.stress]
        @State var search = ""
        var body: some View {
            Form {
                Section("Triggers") {
                    SearchField("Search triggers", text: $search)
                    TriggerPickerSection(selection: $selection, searchText: search)
                }
            }
        }
    }
    return PreviewView()
}
#endif
#endif
