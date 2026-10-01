//
//  TagManagementView.swift
//  MygraFeatureSettings
//
//  Create, edit, reorder, and delete user-defined tags.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct TagManagementView: View {
    @Environment(TagDataModel.self) private var tagData

    @State private var showingAddSheet = false
    @State private var editingTag: MigraineTag?

    public init() {}

    public var body: some View {
        List {
            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add New Tag", systemImage: "plus.circle.fill")
                        .foregroundStyle(.mygraBlue)
                }
            }

            if tagData.tags.isEmpty {
                Section {
                    ContentUnavailableView("No Tags", systemImage: "tag.slash", description: Text("Create tags to categorize your migraines"))
                }
            } else {
                Section("Your Tags") {
                    let rows = ForEach(tagData.tags) { tag in
                        TagRowView(tag: tag) { editingTag = tag }
                    }
                    .onDelete(perform: deleteTags)
                    .onMove(perform: tagData.move)

                    // iOS 27 adds drag-anywhere reordering; earlier releases reorder through Edit mode.
                    if #available(iOS 27.0, *) {
                        rows.reorderable()
                    } else {
                        rows
                    }
                }
            }
        }
        .navigationTitle("Manage Tags")
        .toolbar {
            if !tagData.tags.isEmpty {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            TagEditSheet(mode: .create) { name, colorHex in
                tagData.create(name: name, colorHex: colorHex)
            }
        }
        .sheet(item: $editingTag) { tag in
            TagEditSheet(mode: .edit(tag)) { name, colorHex in
                tagData.update(tag, name: name, colorHex: colorHex)
            }
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            tagData.delete(tagData.tags[index])
        }
    }
}

private struct TagRowView: View {
    let tag: MigraineTag
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 16, height: 16)
                Text(tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(tag.migraineCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(tag.name), \(tag.migraineCount) migraines"))
        .accessibilityHint(Text("Double tap to edit this tag"))
        .accessibilityAddTraits(.isButton)
    }
}

private struct TagEditSheet: View {
    enum Mode {
        case create
        case edit(MigraineTag)
    }

    let mode: Mode
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor: Color = .purple

    private var title: LocalizedStringKey {
        if case .create = mode { return "New Tag" }
        return "Edit Tag"
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let colorOptions: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { color in
                            ColorOptionButton(color: color, isSelected: selectedColor == color) {
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                Section("Preview") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 16, height: 16)
                        Text(name.isEmpty ? String(localized: "Tag Preview") : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), selectedColor.toHex() ?? MigraineTag.defaultColorHex)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if case .edit(let tag) = mode {
                    name = tag.name
                    selectedColor = tag.color
                }
            }
        }
    }
}

private struct ColorOptionButton: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .padding(4)
                    }
                }
                .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Tag Management") {
    NavigationStack {
        TagManagementView()
    }
    .previewEnvironment()
}
#endif
