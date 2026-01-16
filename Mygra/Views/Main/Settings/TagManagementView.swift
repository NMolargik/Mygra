//
//  TagManagementView.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import SwiftUI

/// View for managing user-defined migraine tags.
struct TagManagementView: View {
    @Environment(TagManager.self) private var tagManager

    @State private var showingAddSheet: Bool = false
    @State private var editingTag: MigraineTag? = nil

    var body: some View {
        List {
            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add New Tag", systemImage: "plus.circle.fill")
                        .foregroundStyle(.mygraBlue)
                }
            }

            if tagManager.tags.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("Create tags to categorize your migraines")
                    )
                }
            } else {
                Section("Your Tags") {
                    ForEach(tagManager.tags) { tag in
                        TagRowView(tag: tag) {
                            editingTag = tag
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
            }
        }
        .navigationTitle("Manage Tags")
        .sheet(isPresented: $showingAddSheet) {
            TagEditSheet(
                mode: .create,
                onSave: { name, colorHex in
                    tagManager.create(name: name, colorHex: colorHex)
                }
            )
        }
        .sheet(item: $editingTag) { tag in
            TagEditSheet(
                mode: .edit(tag),
                onSave: { name, colorHex in
                    tagManager.update(tag, name: name, colorHex: colorHex)
                }
            )
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            tagManager.delete(tagManager.tags[index])
        }
    }
}

// MARK: - Tag Row View

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

                Text("\((tag.migraines ?? []).count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Edit Sheet

private struct TagEditSheet: View {
    enum Mode: Identifiable {
        case create
        case edit(MigraineTag)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let tag): return tag.id.uuidString
            }
        }
    }

    let mode: Mode
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: Color = .purple

    private var title: String {
        switch mode {
        case .create: return "New Tag"
        case .edit: return "Edit Tag"
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Predefined color options
    private let colorOptions: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { color in
                            ColorOptionButton(
                                color: color,
                                isSelected: selectedColor == color,
                                onTap: { selectedColor = color }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Preview") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 16, height: 16)
                        Text(name.isEmpty ? "Tag Preview" : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let hex = selectedColor.toHex() ?? "#8B5CF6"
                        onSave(trimmedName, hex)
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
}
