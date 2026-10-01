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
            if tagData.tags.isEmpty {
                ContentUnavailableView {
                    Label("No Tags", systemImage: "tag.slash")
                } description: {
                    Text("Create tags to categorize your migraines")
                } actions: {
                    Button {
                        Haptics.lightImpact()
                        showingAddSheet = true
                    } label: {
                        Label("Add Tag", systemImage: "plus")
                    }
                    .glassActionButton(tint: .mygraPurple)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    let rows = ForEach(tagData.tags) { tag in
                        TagRowView(tag: tag) { editingTag = tag }
                            .contextMenu {
                                Button {
                                    editingTag = tag
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Haptics.error()
                                    tagData.delete(tag)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteTags)
                    .onMove(perform: tagData.move)

                    // iOS 27 adds drag-anywhere reordering; earlier releases reorder through Edit mode.
                    if #available(iOS 27.0, *) {
                        rows.reorderable()
                    } else {
                        rows
                    }
                } header: {
                    Text("Your Tags")
                } footer: {
                    Text("Drag to arrange. Tags appear in this order in the calendar filter.")
                }
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !tagData.tags.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    EditButton()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.lightImpact()
                    showingAddSheet = true
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }
                .accessibilityHint("Creates a new tag")
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
            HStack(spacing: Brand.Space.md) {
                Circle()
                    .fill(tag.color.gradient)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .accessibilityHidden(true)
                Text(tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(tag.migraineCount, format: .number)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
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
    @FocusState private var nameFocused: Bool

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
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Brand.Space.md) {
                        ForEach(colorOptions, id: \.self) { color in
                            ColorOptionButton(color: color, isSelected: selectedColor == color) {
                                Haptics.lightImpact()
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, Brand.Space.sm)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Tag color")
                }
                Section("Preview") {
                    HStack(spacing: Brand.Space.md) {
                        Circle()
                            .fill(selectedColor.gradient)
                            .frame(width: 18, height: 18)
                        Text(name.isEmpty ? String(localized: "Tag Preview") : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                            .contentTransition(.opacity)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if case .edit(let tag) = mode {
                    name = tag.name
                    selectedColor = tag.color
                } else {
                    nameFocused = true
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard isValid else { return }
        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), selectedColor.toHex() ?? MigraineTag.defaultColorHex)
        Haptics.success()
        dismiss()
    }
}

private struct ColorOptionButton: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(Circle().strokeBorder(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2).padding(2))
                .scaleEffect(isSelected ? 1.08 : 1)
                .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 5)
                .animation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Tag Management") {
    NavigationStack {
        TagManagementView()
    }
    .previewEnvironment()
}
#endif
