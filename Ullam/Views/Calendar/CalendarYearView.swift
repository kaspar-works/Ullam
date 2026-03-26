import SwiftUI
import SwiftData

struct CalendarYearView: View {
    @Bindable var diaryManager: DiaryManager
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyMoods: [Int: [Int: String]] = [:]
    @State private var isLoading: Bool = false
    @State private var selectedDay: Int? = nil
    @State private var dayPageCounts: [Int: [Int: Int]] = [:] // [month: [day: count]]
    @State private var showDayEntries = false
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current

    init(diaryManager: DiaryManager) {
        self.diaryManager = diaryManager
        let now = Date()
        self._selectedYear = State(initialValue: Calendar.current.component(.year, from: now))
        self._selectedMonth = State(initialValue: Calendar.current.component(.month, from: now))
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)) else { return "" }
        return formatter.string(from: date)
    }

    private var nextMonthName: String {
        let nextMonth = selectedMonth == 12 ? 1 : selectedMonth + 1
        let nextYear = selectedMonth == 12 ? selectedYear + 1 : selectedYear
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        guard let date = calendar.date(from: DateComponents(year: nextYear, month: nextMonth)) else { return "" }
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Month tabs
                monthTabs
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Month title
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(monthName)
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(.white)

                    Text(String(selectedYear))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)

                // Month subtitle
                Text("A month of quiet reflection and steady growth in\nthe nocturnal hours.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // Filter pills
                HStack(spacing: 24) {
                    Spacer()
                    filterPill(color: AppTheme.dimText, label: "Calm")
                    filterPill(color: AppTheme.accent, label: "Creative")
                    filterPill(color: Color.white.opacity(0.7), label: "Reflective")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Calendar grid
                calendarGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

                // Bottom streak section
                streakSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .task { await loadYearMoods() }
        .sheet(isPresented: $showDayEntries) {
            if let date = selectedDate {
                NavigationStack {
                    DayEntriesView(diaryManager: diaryManager, date: date)
                }
                #if os(macOS)
                .frame(minWidth: 500, minHeight: 400)
                #endif
            }
        }
    }

    // MARK: - Month Tabs

    private var monthTabs: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(monthName) \(String(selectedYear))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Rectangle()
                    .fill(AppTheme.accent)
                    .frame(height: 2)
            }
            .fixedSize()

            VStack(spacing: 4) {
                Text(nextMonthName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
                Rectangle()
                    .fill(.clear)
                    .frame(height: 2)
            }
            .fixedSize()
            .onTapGesture { navigateMonth(by: 1) }

            Spacer()
        }
    }

    // MARK: - Filter Pill

    private func filterPill(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(AppTheme.subtle)
        )
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let daysInMonth = daysInCurrentMonth
        let firstWeekday = firstWeekdayOfMonth
        let weekDays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

        return VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.dimText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // Day cells in rows
            let totalCells = firstWeekday + daysInMonth
            let rows = (totalCells + 6) / 7

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let dayNumber = cellIndex - firstWeekday + 1

                        if dayNumber >= 1 && dayNumber <= daysInMonth {
                            calendarCell(day: dayNumber)
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.clear)
                                .aspectRatio(0.85, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func calendarCell(day: Int) -> some View {
        let emoji = effectiveEmoji(for: day)
        let pageCount = dayPageCounts[selectedMonth]?[day] ?? 0
        let hasEntries = pageCount > 0
        let isToday = calendar.component(.year, from: Date()) == selectedYear &&
                      calendar.component(.month, from: Date()) == selectedMonth &&
                      calendar.component(.day, from: Date()) == day

        return Button {
            // Navigate to this day's entries
            if let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day)) {
                selectedDate = date
                selectedDay = day
                showDayEntries = true
            }
        } label: {
            VStack(spacing: 4) {
                // Day number
                HStack {
                    Text(String(format: "%02d", day))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isToday ? AppTheme.accent : .white.opacity(0.5))
                    Spacer()
                    if hasEntries {
                        Text("\(pageCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.accent.opacity(0.7))
                    }
                }

                Spacer()

                // Emoji mood
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 24))
                }

                // Entry indicator
                if hasEntries && emoji == nil {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.5))
                        .frame(width: 6, height: 6)
                }

                Spacer(minLength: 4)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.85, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedDay == day ? AppTheme.cardBg.opacity(0.15) : AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedDay == day ? AppTheme.accent.opacity(0.4) : .white.opacity(0.04),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 24) {
            // Left: atmospheric image placeholder
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.15, blue: 0.15),
                                Color(red: 0.03, green: 0.08, blue: 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 280)
                    .overlay(
                        Image(systemName: "lamp.desk")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.08))
                    )

                // Quote overlay
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)

                    Text("\"The night is where\nthe ink finds its truest\nsoul.\"")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.8))
                        .italic()
                        .lineSpacing(3)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.5))
                        .background(.ultraThinMaterial.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                )
                .padding(16)
            }
            .frame(maxWidth: .infinity)

            // Right: streak stats
            VStack(alignment: .leading, spacing: 16) {
                Text("CURRENT STREAK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(AppTheme.accent.opacity(0.12))
                    )

                Text("14 Nights of\nConsecutive Reflection")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                // Stat cards
                HStack(spacing: 12) {
                    statCard(value: "82%", label: "EMOTIONAL CLARITY")
                    statCard(value: "21k", label: "WORDS PENNED")
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {} label: {
                        Text("View Detailed Insights")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(AppTheme.accent.opacity(0.7))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {} label: {
                        Text("Export Journal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.dimText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.subtle)
        )
    }

    // MARK: - Helpers

    private var daysInCurrentMonth: Int {
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private var firstWeekdayOfMonth: Int {
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) else { return 0 }
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7 // Monday = 0
    }

    private func effectiveEmoji(for day: Int) -> String? {
        return monthlyMoods[selectedMonth]?[day]
    }

    private func navigateMonth(by offset: Int) {
        var newMonth = selectedMonth + offset
        var newYear = selectedYear

        if newMonth > 12 {
            newMonth = 1
            newYear += 1
        } else if newMonth < 1 {
            newMonth = 12
            newYear -= 1
        }

        selectedMonth = newMonth
        selectedYear = newYear

        Task { await loadYearMoods() }
    }

    private func loadYearMoods() async {
        isLoading = true
        defer { isLoading = false }

        // Load moods
        let moods = diaryManager.getYearMoods(for: selectedYear)
        var newMonthlyMoods: [Int: [Int: String]] = [:]

        for mood in moods {
            let month = calendar.component(.month, from: mood.date)
            let day = calendar.component(.day, from: mood.date)

            if newMonthlyMoods[month] == nil {
                newMonthlyMoods[month] = [:]
            }

            if let emoji = await diaryManager.decryptDayMood(mood) {
                newMonthlyMoods[month]?[day] = emoji
            }
        }

        monthlyMoods = newMonthlyMoods

        // Load page counts per day for the selected month
        var counts: [Int: [Int: Int]] = [:]
        let allPages = diaryManager.getRecentPages(days: 365)
        for page in allPages {
            let m = calendar.component(.month, from: page.date)
            let d = calendar.component(.day, from: page.date)
            let y = calendar.component(.year, from: page.date)
            guard y == selectedYear else { continue }
            if counts[m] == nil { counts[m] = [:] }
            counts[m]?[d, default: 0] += 1
        }
        dayPageCounts = counts
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        CalendarYearView(diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext))
    }
}
