import SwiftUI
import WidgetKit

// MARK: - Writing Goal Widget View

struct WritingGoalWidgetView: View {
    let data: WidgetData
    @Environment(\.widgetFamily) var family

    private var progress: Double {
        guard data.dailyGoal > 0 else { return 0 }
        return min(Double(data.todayWordCount) / Double(data.dailyGoal), 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(WidgetTheme.subtle, lineWidth: 8)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [WidgetTheme.accent, WidgetTheme.gradientPink]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Word count inside ring
                VStack(spacing: 2) {
                    Text("\(data.todayWordCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("words")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetTheme.mutedText)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.bg)
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 20) {
            // Left: progress ring
            ZStack {
                Circle()
                    .stroke(WidgetTheme.subtle, lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [WidgetTheme.accent, WidgetTheme.gradientPink]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(percentage)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 80, height: 80)

            // Right: stats + motivation
            VStack(alignment: .leading, spacing: 8) {
                Text("DAILY GOAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.mutedText)

                Text("\(data.todayWordCount) / \(data.dailyGoal) words")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(motivationalText)
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetTheme.mutedText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.bg)
    }

    // MARK: - Helpers

    private var motivationalText: String {
        if data.todayWordCount == 0 {
            return "Start writing to build momentum"
        } else if progress >= 1.0 {
            return "Goal reached! Keep going"
        } else if progress >= 0.75 {
            return "Almost there, keep writing!"
        } else if progress >= 0.5 {
            return "Great progress, past halfway"
        } else {
            let remaining = data.dailyGoal - data.todayWordCount
            return "\(remaining) words to go"
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    UllamGoalWidget()
} timeline: {
    GoalEntry(date: .now, data: WidgetData(
        currentStreak: 5, todayWordCount: 142, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200, promptText: nil
    ))
}

#Preview("Medium", as: .systemMedium) {
    UllamGoalWidget()
} timeline: {
    GoalEntry(date: .now, data: WidgetData(
        currentStreak: 5, todayWordCount: 142, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200, promptText: nil
    ))
}
