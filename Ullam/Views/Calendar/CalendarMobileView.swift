#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct CalendarMobileView: View {
    @Bindable var diaryManager: DiaryManager
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyMoods: [Int: [Int: String]] = [:]
    @State private var selectedDay: Int? = nil
    @State private var activeMoodFilter: String? = nil
    @State private var appeared = false
    @State private var showDayEntries = false
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current

    private let sampleEmojis: [Int: String] = [
        1: "🦋", 2: "🍏", 3: "🍋", 4: "📚", 5: "💤",
        6: "🕯️", 7: "🌲", 8: "🌙", 9: "📕", 10: "✨",
        11: "🎨", 12: "🌸", 13: "💭", 14: "🌙", 15: "📖",
        16: "✨", 17: "🌿", 18: "😌", 19: "🌙", 20: "☕️",
        21: "🦋", 22: "🌊", 23: "✨", 24: "🍂", 25: "🌙",
        26: "💫"
    ]

    private let moodFilters: [(emoji: String, label: String, color: Color)] = [
        ("💧", "Calm", Color(hex: 0x93C5FD)),
        ("✨", "Creative", Color(hex: 0xA78BFA)),
        ("🌀", "Melancholy", Color(hex: 0xC4B5FD)),
        ("🔥", "Energetic", Color(hex: 0xFDBA74)),
    ]

    private let todayDay: Int

    init(diaryManager: DiaryManager) {
        self.diaryManager = diaryManager
        let now = Date()
        let cal = Calendar.current
        _selectedYear = State(initialValue: cal.component(.year, from: now))
        _selectedMonth = State(initialValue: cal.component(.month, from: now))
        self.todayDay = cal.component(.day, from: now)
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)) else { return "" }
        return formatter.string(from: date)
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        return calendar.component(.year, from: now) == selectedYear &&
               calendar.component(.month, from: now) == selectedMonth
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Month header
                monthHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                // Mood filter chips
                moodChips
                    .padding(.bottom, 20)

                // Weekday headers
                weekdayHeaders
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Calendar grid
                calendarGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)

                // Insight card (glass)
                insightCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Streak card
                streakCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Action buttons
                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
            }
        }
        .background(calendarBackground)
        .task { await loadMoods() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showDayEntries) {
            if let date = selectedDate {
                NavigationStack {
                    DayEntriesView(diaryManager: diaryManager, date: date)
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Background

    private var calendarBackground: some View {
        ZStack {
            // Base gradient (navy → deep purple)
            LinearGradient(
                colors: [
                    Color(hex: 0x0B1120),
                    Color(hex: 0x0F172A),
                    Color(hex: 0x160F2E),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft ambient glow top-left
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 350
            )
            .ignoresSafeArea()

            // Warm glow bottom-right
            RadialGradient(
                colors: [AppTheme.gradientPink.opacity(0.04), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthName)
                    .font(.custom("NewYork-Bold", size: 38, relativeTo: .largeTitle))
                    .foregroundStyle(.white)

                Text(String(selectedYear))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.accent.opacity(0.8))
            }

            Spacer()

            // Month navigation
            HStack(spacing: 4) {
                Button {
                    navigateMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(CalendarButtonStyle())

                Button {
                    navigateMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(CalendarButtonStyle())
            }
        }
    }

    // MARK: - Mood Chips

    private var moodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(moodFilters, id: \.label) { filter in
                    let isActive = activeMoodFilter == filter.label
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            activeMoodFilter = isActive ? nil : filter.label
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Text(filter.emoji)
                                .font(.system(size: 14))

                            Text(filter.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isActive ? .white : .white.opacity(0.5))

                            if isActive {
                                Text("32%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(filter.color.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isActive ? filter.color.opacity(0.15) : .white.opacity(0.04))
                                .overlay(
                                    Capsule()
                                        .stroke(isActive ? filter.color.opacity(0.3) : .white.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .shadow(color: isActive ? filter.color.opacity(0.15) : .clear, radius: 8, y: 2)
                    }
                    .buttonStyle(CalendarButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let daysInMonth = daysCount
        let firstDay = firstWeekday
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            // Empty leading cells
            ForEach(0..<firstDay, id: \.self) { _ in
                Color.clear.frame(height: 52)
            }

            // Day cells
            ForEach(1...daysInMonth, id: \.self) { day in
                let emoji = effectiveEmoji(for: day)
                let isToday = isCurrentMonth && day == todayDay
                let isSelected = selectedDay == day
                let hasStreak = hasStreakConnection(day: day)
                let cellIndex = firstDay + day - 1

                CalendarDayCellView(
                    day: day,
                    emoji: emoji,
                    isToday: isToday,
                    isSelected: isSelected,
                    hasStreak: hasStreak
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(cellIndex) * 0.015),
                    value: appeared
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedDay = isSelected ? nil : day
                    }
                    // Open day detail
                    if let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day)) {
                        selectedDate = date
                        showDayEntries = true
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    // MARK: - Insight Card (Glass)

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("\(monthName) Insight")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }

            // Insight text with highlighted keywords
            (Text("Your month has been characterized by deep ")
                .foregroundStyle(.white.opacity(0.5))
             + Text("tranquility")
                .foregroundStyle(AppTheme.moodCalm)
                .bold()
             + Text(", with a notable streak of ")
                .foregroundStyle(.white.opacity(0.5))
             + Text("8 day-deep days")
                .foregroundStyle(AppTheme.accent)
                .bold()
             + Text(" early on. Reflections often center around ")
                .foregroundStyle(.white.opacity(0.5))
             + Text("creative flow")
                .foregroundStyle(Color(hex: 0xA78BFA))
                .bold()
             + Text(" and ")
                .foregroundStyle(.white.opacity(0.5))
             + Text("evening rituals")
                .foregroundStyle(AppTheme.gradientPink.opacity(0.8))
                .bold()
             + Text(".")
                .foregroundStyle(.white.opacity(0.5)))
                .font(.system(size: 14))
                .lineSpacing(6)

            // Stats row
            HStack(spacing: 16) {
                miniStat(value: "26", label: "Days logged", color: AppTheme.accent)
                miniStat(value: "84%", label: "Consistency", color: Color(hex: 0x34D399))
                miniStat(value: "4.2k", label: "Words", color: AppTheme.gradientPink)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.08), .white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.gradientPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("13")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("days")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xFDBA74), Color(hex: 0xF97316)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("You're on fire!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("13-day writing streak. Your longest this year. Every page is a gift to your future self.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFDBA74).opacity(0.06), Color(hex: 0xF97316).opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: 0xFDBA74).opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Primary (gradient + glow)
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Full Report")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color(hex: 0x7C3AED)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: AppTheme.accent.opacity(0.25), radius: 12, y: 4)
            }
            .buttonStyle(CalendarButtonStyle())

            // Secondary (outline)
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Export PDF")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.04))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(CalendarButtonStyle())
        }
    }

    // MARK: - Navigation

    private func navigateMonth(by offset: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            appeared = false
        }

        var newMonth = selectedMonth + offset
        var newYear = selectedYear
        if newMonth > 12 { newMonth = 1; newYear += 1 }
        else if newMonth < 1 { newMonth = 12; newYear -= 1 }
        selectedMonth = newMonth
        selectedYear = newYear
        selectedDay = nil

        Task { await loadMoods() }

        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            appeared = true
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

    private func hasStreakConnection(day: Int) -> Bool {
        // Check if both this day and previous day have moods
        return effectiveEmoji(for: day) != nil && effectiveEmoji(for: day - 1) != nil
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

// MARK: - Day Cell View

private struct CalendarDayCellView: View {
    let day: Int
    let emoji: String?
    let isToday: Bool
    let isSelected: Bool
    let hasStreak: Bool

    @State private var pressed = false

    var body: some View {
        ZStack {
            // Selection ring (gradient)
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.gradientPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 8)
            }

            // Background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(emoji != nil ? 0.06 : 0.03), lineWidth: 1)
                )

            // Content
            VStack(spacing: 2) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                } else {
                    Text("\(day)")
                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? AppTheme.accent : .white.opacity(0.2))
                }

                // Today dot
                if isToday && emoji == nil {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 4, height: 4)
                }
            }

            // Streak glow (left edge)
            if hasStreak && emoji != nil {
                HStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AppTheme.accent.opacity(0.3))
                        .frame(width: 2, height: 20)
                    Spacer()
                }
                .padding(.leading, 2)
            }
        }
        .frame(height: 52)
        .scaleEffect(pressed ? 0.92 : (isSelected ? 1.02 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }

    private var cellBackground: Color {
        if isSelected {
            return AppTheme.accent.opacity(0.12)
        } else if emoji != nil {
            return .white.opacity(0.05)
        } else {
            return .white.opacity(0.02)
        }
    }
}

// MARK: - Button Style

private struct CalendarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#endif // os(iOS)
