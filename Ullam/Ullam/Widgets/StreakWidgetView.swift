import SwiftUI
import WidgetKit

// MARK: - Streak Widget View

struct StreakWidgetView: View {
    let data: WidgetData
    @Environment(\.widgetFamily) var family

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
        VStack(spacing: 8) {
            Text("\u{1F525}")
                .font(.system(size: 32))

            Text("\(data.currentStreak)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.accent)

            Text(data.currentStreak == 1 ? "day" : "days")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetTheme.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.bg)
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 20) {
            // Left: streak number with flame
            VStack(spacing: 4) {
                Text("\u{1F525}")
                    .font(.system(size: 28))

                Text("\(data.currentStreak)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.accent)
            }
            .frame(width: 90)

            // Right: label + week dots
            VStack(alignment: .leading, spacing: 12) {
                Text("\(data.currentStreak) day streak")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Keep the momentum going")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetTheme.mutedText)

                // Mini progress dots for the week (Mon-Sun)
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        let isFilled = index < min(data.currentStreak, 7)
                        Circle()
                            .fill(isFilled ? WidgetTheme.accent : WidgetTheme.subtle)
                            .frame(width: 10, height: 10)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.bg)
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    UllamStreakWidget()
} timeline: {
    StreakEntry(date: .now, data: WidgetData(
        currentStreak: 12, todayWordCount: 142, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200, promptText: nil
    ))
}

#Preview("Medium", as: .systemMedium) {
    UllamStreakWidget()
} timeline: {
    StreakEntry(date: .now, data: WidgetData(
        currentStreak: 5, todayWordCount: 142, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200, promptText: nil
    ))
}
