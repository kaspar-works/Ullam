import SwiftUI
import WidgetKit

// MARK: - Mood Widget View

struct MoodWidgetView: View {
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
            if let mood = data.todayMood {
                Text(mood)
                    .font(.system(size: 56))
            } else {
                noMoodSmall
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.bg)
    }

    private var noMoodSmall: some View {
        VStack(spacing: 8) {
            Text("?")
                .font(.system(size: 40, weight: .light, design: .serif))
                .foregroundStyle(WidgetTheme.accent.opacity(0.6))

            Text("How are you?")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.mutedText)
        }
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 20) {
            if let mood = data.todayMood {
                // Left: large emoji
                Text(mood)
                    .font(.system(size: 52))
                    .frame(width: 80)

                // Right: label + date
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's mood")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(WidgetTheme.mutedText)

                    Text(formattedDate)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    if let title = data.lastEntryTitle {
                        Text(title)
                            .font(.system(size: 12))
                            .foregroundStyle(WidgetTheme.mutedText)
                            .lineLimit(1)
                    }
                }

                Spacer()
            } else {
                noMoodMedium
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.bg)
    }

    private var noMoodMedium: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(WidgetTheme.accent.opacity(0.1))
                    .frame(width: 60, height: 60)

                Text("?")
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .foregroundStyle(WidgetTheme.accent.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("How are you feeling?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Tap to set your mood for today")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetTheme.mutedText)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Preview

#Preview("Small - With Mood", as: .systemSmall) {
    UllamMoodWidget()
} timeline: {
    MoodEntry(date: .now, data: WidgetData(
        currentStreak: 5, todayWordCount: 142, todayMood: "\u{1F31F}",
        lastEntryTitle: "A quiet afternoon", lastEntryDate: .now, dailyGoal: 200, promptText: nil
    ))
}

#Preview("Small - No Mood", as: .systemSmall) {
    UllamMoodWidget()
} timeline: {
    MoodEntry(date: .now, data: WidgetData(
        currentStreak: 5, todayWordCount: 0, todayMood: nil,
        lastEntryTitle: nil, lastEntryDate: nil, dailyGoal: 200, promptText: nil
    ))
}
