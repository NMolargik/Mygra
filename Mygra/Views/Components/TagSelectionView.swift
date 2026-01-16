//
//  TagSelectionView.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import SwiftUI

/// A reusable view for selecting tags when creating or editing a migraine.
struct TagSelectionView: View {
    @Environment(TagManager.self) private var tagManager
    @Binding var selectedTags: [MigraineTag]?

    var body: some View {
        Section("Tags") {
            if tagManager.tags.isEmpty {
                Text("No tags created yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                NavigationLink {
                    TagManagementView()
                } label: {
                    Label("Create Tags", systemImage: "plus.circle")
                        .foregroundStyle(.mygraBlue)
                }
            } else {
                ForEach(tagManager.tags) { tag in
                    TagToggleRow(
                        tag: tag,
                        isSelected: (selectedTags ?? []).contains { $0.id == tag.id },
                        onToggle: { toggleTag(tag) }
                    )
                }

                NavigationLink {
                    TagManagementView()
                } label: {
                    Label("Manage Tags", systemImage: "tag.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggleTag(_ tag: MigraineTag) {
        if selectedTags == nil {
            selectedTags = []
        }
        if let index = (selectedTags ?? []).firstIndex(where: { $0.id == tag.id }) {
            selectedTags?.remove(at: index)
        } else {
            selectedTags?.append(tag)
        }
    }
}

// MARK: - Tag Toggle Row

private struct TagToggleRow: View {
    let tag: MigraineTag
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 12, height: 12)

                Text(tag.name)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.mygraBlue)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Tag Selection") {
    NavigationStack {
        Form {
            TagSelectionView(selectedTags: .constant([]))
        }
    }
}
