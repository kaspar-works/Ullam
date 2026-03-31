import SwiftUI

#if os(iOS)
import UIKit

// MARK: - Floating Format Toolbar

struct FloatingToolbar: View {
    @Binding var formatAction: FormatAction?
    @Binding var selectedEmojis: [String]
    @Binding var isExpanded: Bool
    var showingEmojiPicker: Binding<Bool>
    var showingImagePicker: Binding<Bool>
    var showingInsertMenu: Binding<Bool>
    var onVoiceTap: () -> Void
    var onDismissKeyboard: () -> Void
    var onSketchTap: (() -> Void)?
    var isListening: Bool
    let maxEmojis: Int

    @State private var activeSection: ToolbarSection? = nil

    enum ToolbarSection: String, CaseIterable {
        case format = "Format"
        case style = "Style"
        case insert = "Insert"
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedToolbar
            } else {
                compactToolbar
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeSection)
    }

    // MARK: - Compact Toolbar

    private var compactToolbar: some View {
        HStack(spacing: 0) {
            // Emoji
            HStack(spacing: 4) {
                ForEach(Array(selectedEmojis.enumerated()), id: \.offset) { index, emoji in
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            selectedEmojis.remove(at: index)
                        }
                        haptic(.light)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 16))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.subtle)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                if selectedEmojis.count < maxEmojis {
                    toolBtn(icon: "face.smiling") { showingEmojiPicker.wrappedValue = true }
                }
            }

            Spacer()

            // Quick format
            HStack(spacing: 2) {
                toolBtn(icon: "bold") { formatAction = .bold }
                    .accessibilityLabel("Bold")
                toolBtn(icon: "italic") { formatAction = .italic }
                    .accessibilityLabel("Italic")
                toolBtn(icon: "underline") { formatAction = .underline }
                    .accessibilityLabel("Underline")
            }

            Spacer()

            // Voice
            Button {
                onVoiceTap()
                haptic(.light)
            } label: {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isListening ? .red : AppTheme.mutedText)
                    .frame(width: 34, height: 34)
                    .background(isListening ? Color.red.opacity(0.15) : AppTheme.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isListening ? Color.red.opacity(0.3) : .clear, lineWidth: 1)
                    )
            }
            .buttonStyle(TBStyle())
            .accessibilityLabel(isListening ? "Stop recording" : "Start voice recording")

            Spacer().frame(width: 6)

            // Expand
            toolBtn(icon: "ellipsis") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }

            Spacer().frame(width: 4)

            // Dismiss keyboard
            Button {
                onDismissKeyboard()
                haptic(.light)
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(TBStyle())
            .accessibilityLabel("Dismiss keyboard")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .padding(.horizontal, 10)
    }

    // MARK: - Expanded Toolbar

    private var expandedToolbar: some View {
        VStack(spacing: 8) {
            // Section tabs + collapse
            HStack(spacing: 4) {
                ForEach(ToolbarSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            activeSection = activeSection == section ? nil : section
                        }
                        haptic(.light)
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(activeSection == section ? .white : AppTheme.dimText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(activeSection == section ? AppTheme.accent.opacity(0.35) : AppTheme.subtle)
                            )
                    }
                    .buttonStyle(TBStyle())
                }

                Spacer()

                // Dismiss keyboard
                Button {
                    onDismissKeyboard()
                    haptic(.light)
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.dimText)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.subtle)
                        .clipShape(Circle())
                }
                .buttonStyle(TBStyle())

                // Collapse
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = false
                        activeSection = nil
                    }
                    haptic(.light)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.dimText)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.subtle)
                        .clipShape(Circle())
                }
                .buttonStyle(TBStyle())
            }
            .padding(.horizontal, 4)

            // Section content
            if let section = activeSection {
                sectionContent(section)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
        )
        .padding(.horizontal, 10)
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(_ section: ToolbarSection) -> some View {
        switch section {
        case .format:
            formatSection
        case .style:
            styleSection
        case .insert:
            insertSection
        }
    }

    private var formatSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                toolBtn(icon: "bold") { formatAction = .bold }
                toolBtn(icon: "italic") { formatAction = .italic }
                toolBtn(icon: "underline") { formatAction = .underline }
                toolBtn(icon: "strikethrough") { formatAction = .strikethrough }

                divider

                toolBtn(icon: "highlighter") { formatAction = .highlight }

                divider

                textBtn("H1") { formatAction = .heading }
                textBtn("H2") { formatAction = .subheading }
                textBtn("T") { formatAction = .body }

                divider

                toolBtn(icon: "arrow.uturn.backward") {
                    // Undo handled by system
                    UIApplication.shared.sendAction(#selector(UndoManager.undo), to: nil, from: nil, for: nil)
                }
                toolBtn(icon: "arrow.uturn.forward") {
                    UIApplication.shared.sendAction(#selector(UndoManager.redo), to: nil, from: nil, for: nil)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var styleSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                toolBtn(icon: "text.quote") { formatAction = .quote }
                toolBtn(icon: "list.bullet") { formatAction = .bulletList }
                toolBtn(icon: "list.number") { formatAction = .numberedList }
                toolBtn(icon: "checklist") { formatAction = .bulletList }

                divider

                toolBtn(icon: "minus") { formatAction = .separator }

                divider

                // Emoji tags
                if selectedEmojis.count < maxEmojis {
                    toolBtn(icon: "face.smiling") { showingEmojiPicker.wrappedValue = true }
                }
                ForEach(Array(selectedEmojis.enumerated()), id: \.offset) { index, emoji in
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            selectedEmojis.remove(at: index)
                        }
                        haptic(.light)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 16))
                            .frame(width: 34, height: 34)
                            .background(AppTheme.subtle)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(TBStyle())
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var insertSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                insertBtn(icon: "photo", label: "Photo") {
                    showingImagePicker.wrappedValue = true
                }
                insertBtn(icon: "camera", label: "Camera") {
                    showingInsertMenu.wrappedValue = true
                }
                insertBtn(icon: "mic.fill", label: isListening ? "Stop" : "Voice") {
                    onVoiceTap()
                }
                insertBtn(icon: "checklist", label: "List") {
                    formatAction = .bulletList
                }
                insertBtn(icon: "text.quote", label: "Quote") {
                    formatAction = .quote
                }
                insertBtn(icon: "minus", label: "Divider") {
                    formatAction = .separator
                }
                if let onSketchTap {
                    insertBtn(icon: "pencil.tip", label: "Sketch") {
                        onSketchTap()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Button Helpers

    private func toolBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
                .frame(minWidth: 44, minHeight: 44)
                .background(AppTheme.subtle)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(TBStyle())
    }

    private func textBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.mutedText)
                .frame(width: 34, height: 34)
                .background(AppTheme.subtle)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(TBStyle())
    }

    private func insertBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.dimText)
            }
            .frame(width: 56, height: 50)
            .background(AppTheme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(TBStyle())
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.subtle)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Toolbar Button Style

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TBStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#endif
