import SwiftUI
import WidgetKit

// MARK: - Prompt Widget View

struct PromptWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetTheme.accent)

                Text("WRITING PROMPT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.mutedText)

                Spacer()
            }

            Spacer().frame(height: 12)

            // Prompt text
            if let prompt = data.promptText {
                Text(prompt)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .lineSpacing(4)
            } else {
                Text("What would you tell your future self today?")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                    .lineSpacing(4)
            }

            Spacer()

            // CTA
            HStack {
                Spacer()

                Text("Tap to write")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accent)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                WidgetTheme.bg

                // Subtle gradient border overlay
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                WidgetTheme.accent.opacity(0.3),
                                WidgetTheme.gradientPink.opacity(0.2),
                                WidgetTheme.accent.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .padding(1)
            }
        )
    }
}

// MARK: - Preview

#Preview("Medium", as: .systemMedium) {
    UllamPromptWidget()
} timeline: {
    PromptEntry(date: .now, data: WidgetData(
        currentStreak: 5, todayWordCount: 0, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200,
        promptText: "Describe a sound that always brings you comfort, no matter where you are."
    ))
}

#Preview("Medium - No Prompt", as: .systemMedium) {
    UllamPromptWidget()
} timeline: {
    PromptEntry(date: .now, data: WidgetData(
        currentStreak: 0, todayWordCount: 0, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200, promptText: nil
    ))
}
