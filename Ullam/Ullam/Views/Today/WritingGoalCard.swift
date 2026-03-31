#if os(iOS)
import SwiftUI

struct WritingGoalCard: View {
    @Bindable var diaryManager: DiaryManager
    let goal: Int

    @State private var wordCount: Int = 0
    @State private var percentage: Double = 0.0
    @State private var animatedPercentage: Double = 0.0
    @State private var showCelebration = false
    @State private var appeared = false

    private var progressColor: Color {
        if percentage >= 1.0 {
            return Color(hex: 0x34D399) // green
        } else if percentage >= 0.7 {
            return AppTheme.accent
        } else if percentage >= 0.4 {
            return AppTheme.gradientPurple.opacity(0.7)
        } else {
            return AppTheme.mutedText.opacity(0.25)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(AppTheme.subtle, lineWidth: 4)
                    .frame(width: 48, height: 48)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedPercentage)
                    .stroke(
                        AngularGradient(
                            colors: [progressColor.opacity(0.3), progressColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                // Center content
                if showCelebration {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x34D399))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(progressColor)
                }
            }

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("\(wordCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(" / \(goal) words")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.dimText)
                }

                if showCelebration {
                    Text("Goal reached! Great writing today.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                        .transition(.opacity)
                } else {
                    Text("Daily writing goal")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.dimText)
                }
            }

            Spacer()

            // Celebration sparkles
            if showCelebration {
                celebrationSparkles
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            showCelebration
                            ? Color(hex: 0x34D399).opacity(0.15)
                            : AppTheme.subtle,
                            lineWidth: 1
                        )
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .task { await loadProgress() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Celebration Sparkles

    private var celebrationSparkles: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat([8, 10, 6][i])))
                    .foregroundStyle(Color(hex: 0x34D399).opacity(Double([0.6, 0.4, 0.8][i])))
                    .offset(
                        x: CGFloat([-8, 6, 0][i]),
                        y: CGFloat([6, -8, 4][i])
                    )
                    .scaleEffect(showCelebration ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.5)
                        .delay(Double(i) * 0.1),
                        value: showCelebration
                    )
            }
        }
        .frame(width: 24, height: 24)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Data

    private func loadProgress() async {
        let progress = await WritingGoalService.shared.getGoalProgress(
            diaryManager: diaryManager,
            goal: goal
        )
        wordCount = progress.words
        percentage = progress.percentage

        // Animate the ring
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            animatedPercentage = progress.percentage
        }

        // Celebration if goal reached
        if progress.percentage >= 1.0 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.8)) {
                showCelebration = true
            }
        }
    }
}
#endif
