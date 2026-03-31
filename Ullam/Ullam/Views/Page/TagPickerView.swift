#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct TagPickerView: View {
    let page: Page
    let diary: Diary
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var allTags: [Tag] = []
    @State private var selectedTagIds: Set<UUID> = []
    @State private var showCreateForm = false
    @State private var newTagName = ""
    @State private var newTagColor = "purple"

    private let presetColors: [(key: String, label: String)] = [
        ("blue", "Blue"),
        ("orange", "Orange"),
        ("purple", "Purple"),
        ("pink", "Pink"),
        ("green", "Green"),
        ("yellow", "Yellow"),
        ("red", "Red"),
        ("indigo", "Indigo"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Tag grid
                        tagGrid
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // Create tag section
                        createTagSection
                            .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applySelection()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .onAppear { loadTags() }
        }
    }

    // MARK: - Tag Grid

    private var tagGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 90, maximum: 200), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(allTags, id: \.id) { tag in
                tagCapsule(tag)
            }
        }
    }

    private func tagCapsule(_ tag: Tag) -> some View {
        let isSelected = selectedTagIds.contains(tag.id)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedTagIds.remove(tag.id)
                } else {
                    selectedTagIds.insert(tag.id)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Text(tag.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.sage)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(colorForKey(tag.color).opacity(isSelected ? 0.25 : 0.08))
                    .overlay(
                        Capsule()
                            .stroke(colorForKey(tag.color).opacity(isSelected ? 0.5 : 0.15), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(TagPickerButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Create Tag Section

    private var createTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) { showCreateForm.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent.opacity(0.6))
                    Text("Create Tag")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent.opacity(0.7))
                }
            }

            if showCreateForm {
                VStack(spacing: 12) {
                    // Name field
                    TextField("Tag name", text: $newTagName)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.subtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.subtle, lineWidth: 1)
                                )
                        )

                    // Color picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presetColors, id: \.key) { preset in
                                Button {
                                    newTagColor = preset.key
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(colorForKey(preset.key))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(newTagColor == preset.key ? AppTheme.sage : .clear, lineWidth: 2)
                                        )
                                        .scaleEffect(newTagColor == preset.key ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.25), value: newTagColor)
                                }
                            }
                        }
                    }

                    // Create button
                    Button {
                        createNewTag()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("Add Tag")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.accent.opacity(newTagName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.2 : 0.5))
                            )
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.subtle)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.subtle, lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Actions

    private func loadTags() {
        allTags = TagService.shared.getAllTags(for: diary, context: modelContext)
        selectedTagIds = Set(page.tagIds)
    }

    private func applySelection() {
        // Remove tags no longer selected
        let currentIds = Set(page.tagIds)
        let toRemove = currentIds.subtracting(selectedTagIds)
        let toAdd = selectedTagIds.subtracting(currentIds)

        for tag in allTags {
            if toRemove.contains(tag.id) {
                TagService.shared.removeTag(tag, from: page)
            }
            if toAdd.contains(tag.id) {
                TagService.shared.addTag(tag, to: page)
            }
        }

        try? modelContext.save()
    }

    private func createNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let tag = TagService.shared.createTag(name: name, color: newTagColor, diary: diary, context: modelContext)
        allTags.append(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
        withAnimation(.spring(response: 0.3)) { showCreateForm = false }
    }

    // MARK: - Helpers

    private func colorForKey(_ key: String) -> Color {
        switch key {
        case "blue": return AppTheme.gradientBlue
        case "orange": return AppTheme.moodHappy
        case "purple": return AppTheme.gradientPurple
        case "pink": return AppTheme.gradientPink
        case "green": return Color(hex: 0x34D399)
        case "yellow": return Color(hex: 0xFDE68A)
        case "red": return Color(hex: 0xF87171)
        case "indigo": return AppTheme.indigo
        default: return AppTheme.accent
        }
    }
}

private struct TagPickerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
#endif
