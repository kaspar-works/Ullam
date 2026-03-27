import SwiftUI

#if os(iOS)
import UIKit

// MARK: - AI Writing Suggestion Sheet

struct AIWritingSheet: View {
    @Binding var isPresented: Bool
    var onAction: (AIWritingAction) -> Void

    @State private var selectedAction: AIWritingAction?
    @State private var isProcessing = false

    enum AIWritingAction: String, CaseIterable, Identifiable {
        case improve = "Improve Writing"
        case summarize = "Summarize"
        case rewrite = "Rewrite"
        case expand = "Expand"
        case fixGrammar = "Fix Grammar"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .improve: return "sparkles"
            case .summarize: return "text.justify.leading"
            case .rewrite: return "arrow.triangle.2.circlepath"
            case .expand: return "text.insert"
            case .fixGrammar: return "checkmark.circle"
            }
        }

        var description: String {
            switch self {
            case .improve: return "Enhance clarity, flow, and tone"
            case .summarize: return "Create a concise summary"
            case .rewrite: return "Rephrase with a fresh perspective"
            case .expand: return "Add depth and detail"
            case .fixGrammar: return "Correct spelling and grammar"
            }
        }

        var gradient: [Color] {
            switch self {
            case .improve: return [Color(hex: 0xA78BFA), Color(hex: 0x7C3AED)]
            case .summarize: return [Color(hex: 0x60A5FA), Color(hex: 0x3B82F6)]
            case .rewrite: return [Color(hex: 0xF472B6), Color(hex: 0xEC4899)]
            case .expand: return [Color(hex: 0x34D399), Color(hex: 0x10B981)]
            case .fixGrammar: return [Color(hex: 0xFBBF24), Color(hex: 0xF59E0B)]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // Header
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.gradientPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Writing Assistant")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Enhance your writing with AI")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(ToolbarButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Action cards
            VStack(spacing: 10) {
                ForEach(AIWritingAction.allCases) { action in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedAction = action
                        isProcessing = true

                        // Simulate processing then callback
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onAction(action)
                            isProcessing = false
                            isPresented = false
                        }
                    } label: {
                        HStack(spacing: 14) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: action.gradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 38, height: 38)

                                Image(systemName: action.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(action.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(action.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            Spacer()

                            if isProcessing && selectedAction == action {
                                ProgressView()
                                    .tint(.white.opacity(0.5))
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(ToolbarButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .ignoresSafeArea()
        )
    }
}

// MARK: - Keyboard Accessory Bar

struct EditorKeyboardAccessory: View {
    var onAITap: () -> Void
    var onImageTap: () -> Void
    var onChecklistTap: () -> Void
    var onVoiceTap: () -> Void
    var onDismissKeyboard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            accessoryButton(icon: "sparkles", label: "AI") { onAITap() }

            Divider().frame(height: 18).opacity(0.15)

            accessoryButton(icon: "photo", label: nil) { onImageTap() }

            accessoryButton(icon: "checklist", label: nil) { onChecklistTap() }

            accessoryButton(icon: "mic", label: nil) { onVoiceTap() }

            Spacer()

            Button {
                onDismissKeyboard()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }

    private func accessoryButton(icon: String, label: String?, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(icon == "sparkles" ?
                AnyShapeStyle(LinearGradient(
                    colors: [AppTheme.accent, AppTheme.gradientPink],
                    startPoint: .leading,
                    endPoint: .trailing
                )) :
                AnyShapeStyle(.white.opacity(0.5))
            )
            .padding(.horizontal, 12)
            .frame(height: 36)
        }
        .buttonStyle(ToolbarButtonStyle())
    }
}

#endif
