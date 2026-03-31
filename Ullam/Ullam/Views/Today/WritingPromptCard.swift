import SwiftUI
import SwiftData

#if os(iOS)

struct WritingPromptCard: View {
    @Bindable var diaryManager: DiaryManager
    let promptService: WritingPromptService
    var onCreatePage: ((_ subtitle: String) -> Void)?

    @State private var currentPrompt: WritingPrompt?
    @State private var appeared = false
    @State private var isRefreshing = false

    private var categoryColor: Color {
        switch currentPrompt?.category {
        case "reflection": return AppTheme.gradientBlue
        case "gratitude": return AppTheme.moodLove
        case "creative": return AppTheme.gradientPurple
        case "dream": return AppTheme.moodCalm
        case "anxiety": return AppTheme.moodSad
        default: return AppTheme.accent
        }
    }

    private var categoryLabel: String {
        currentPrompt?.category.capitalized ?? "Prompt"
    }

    var body: some View {
        Group {
            if let prompt = currentPrompt {
                cardContent(prompt)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1), value: appeared)
            }
        }
        .onAppear {
            if currentPrompt == nil {
                currentPrompt = promptService.getDailyPrompt()
            }
            withAnimation { appeared = true }
        }
    }

    // MARK: - Card

    private func cardContent(_ prompt: WritingPrompt) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category chip
            HStack(spacing: 8) {
                Text(categoryLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(categoryColor.opacity(0.15))
                    )

                Spacer()

                // Refresh button
                Button {
                    refreshPrompt()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.dimText)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
                .buttonStyle(FeedPromptButtonStyle())
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

            // Prompt text
            Text(prompt.text)
                .font(.custom("NewYork-Regular", size: 19, relativeTo: .title3))
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

            // Action button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCreatePage?(prompt.text)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 13, weight: .medium))
                    Text("Write about this")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.6), AppTheme.accent.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(FeedPromptButtonStyle())
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    categoryColor.opacity(0.3),
                                    AppTheme.subtle,
                                    categoryColor.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func refreshPrompt() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isRefreshing = true
        }

        // Brief fade-out then swap
        withAnimation(.easeOut(duration: 0.2)) {
            appeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentPrompt = promptService.refreshPrompt()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
                isRefreshing = false
            }
        }
    }
}

// MARK: - Button Style

private struct FeedPromptButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#endif
