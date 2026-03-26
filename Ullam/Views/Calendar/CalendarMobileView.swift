#if os(iOS)
import SwiftUI
import SwiftData

struct CalendarMobileView: View {
    @Bindable var diaryManager: DiaryManager
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyMoods: [Int: [Int: String]] = [:]

    private let calendar = Calendar.current

    private let sampleEmojis: [Int: String] = [
        1: "🌙", 2: "☕️", 3: "☁️", 4: "✨", 5: "🍂", 6: "💤",
        7: "🕯️", 8: "🌲", 9: "🦋", 10: "🍏", 11: "🍋", 12: "🌊",
        14: "☁️", 18: "✏️", 20: "📖", 22: "🎵", 25: "💫"
    ]

    private let moodFilters = [
        ("💧", "Calm"), ("✨", "Creative"), ("🌀", "Melancholy")
    ]

    init(diaryManager: DiaryManager) {
        self.diaryManager = diaryManager
        let now = Date()
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: now))
        _selectedMonth = State(initialValue: Calendar.current.component(.month, from: now))
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)) else { return "" }
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Month header
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(monthName)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(.white)

                    Text(String(selectedYear))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)

                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(moodFilters, id: \.1) { emoji, label in
                            HStack(spacing: 4) {
                                Text(emoji).font(.system(size: 12))
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(AppTheme.subtle))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)

                // Emoji calendar grid
                emojiGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                // October Insight
                insightSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // Streak banner
                streakBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .background(AppTheme.bg)
        .task { await loadMoods() }
    }

    // MARK: - Emoji Grid

    private var emojiGrid: some View {
        let daysInMonth = daysCount
        let firstDay = firstWeekday
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return LazyVGrid(columns: columns, spacing: 6) {
            // Empties
            ForEach(0..<firstDay, id: \.self) { _ in
                Color.clear.frame(height: 44)
            }

            // Days
            ForEach(1...daysInMonth, id: \.self) { day in
                let emoji = effectiveEmoji(for: day)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(emoji != nil ? AppTheme.accent.opacity(0.12) : AppTheme.subtle)
                        .frame(height: 44)

                    if let emoji = emoji {
                        Text(emoji)
                            .font(.system(size: 18))
                    } else {
                        Text("\(day)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
            }
        }
    }

    // MARK: - Insight

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(monthName) Insight")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text("Your month has been characterized by deep **tranquility**, with a notable streak of 8 day-deep days early on. Reflections often center around creative flow and evening rituals.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.mutedText)
                .lineSpacing(4)

            // Action buttons
            HStack(spacing: 10) {
                Button {} label: {
                    Text("Full Report")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.6)))
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Text("Export PDF")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppTheme.subtle))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Streak

    private var streakBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reflect on the streak.")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("You've logged 13 days in a row. Keep the momentum.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.subtle)
        )
    }

    // MARK: - Helpers

    private var daysCount: Int {
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private var firstWeekday: Int {
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) else { return 0 }
        return (calendar.component(.weekday, from: date) + 5) % 7
    }

    private func effectiveEmoji(for day: Int) -> String? {
        if let moodData = monthlyMoods[selectedMonth], let emoji = moodData[day] {
            return emoji
        }
        return sampleEmojis[day]
    }

    private func loadMoods() async {
        let moods = diaryManager.getYearMoods(for: selectedYear)
        var result: [Int: [Int: String]] = [:]
        for mood in moods {
            let m = calendar.component(.month, from: mood.date)
            let d = calendar.component(.day, from: mood.date)
            if result[m] == nil { result[m] = [:] }
            if let emoji = await diaryManager.decryptDayMood(mood) {
                result[m]?[d] = emoji
            }
        }
        monthlyMoods = result
    }
}
#endif // os(iOS)
