#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct CalendarMobileView: View {
    @Bindable var diaryManager: DiaryManager

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var contrast

    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyMoods: [Int: [Int: String]] = [:]
    @State private var selectedDay: Int? = nil
    @State private var activeMoodFilter: String? = nil
    @State private var appeared = false
    @State private var showDayEntries = false
    @State private var selectedDate: Date? = nil
    @State private var monthDirection: Int = 0 // -1 left, 1 right
    @State private var streakRingProgress: CGFloat = 0
    @State private var cardsAppeared = false
    @State private var monthNameOffset: CGFloat = 0
    @State private var monthNameOpacity: Double = 1
    @State private var showMoodTrends = false

    private let calendar = Calendar.current

    // Page emojis: [month: [day: emoji]] — from the latest page entry per day
    @State private var monthlyPageEmojis: [Int: [Int: String]] = [:]

    private let moodFilters: [(emoji: String, label: String, color: Color)] = [
        ("💧", "Calm", AppTheme.moodCalm),
        ("✨", "Creative", AppTheme.accent),
        ("🌀", "Melancholy", AppTheme.moodSad),
        ("🔥", "Energetic", AppTheme.moodHappy),
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
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: cardsAppeared)

                // Streak card
                streakCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.45), value: cardsAppeared)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue("13 day writing streak")

                // Action buttons
                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 15)
                    .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.55), value: cardsAppeared)
            }
        }
        .background(calendarBackground)
        .task { await loadMoods() }
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5).delay(0.2)) {
                cardsAppeared = true
            }
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 1.0).delay(0.6)) {
                streakRingProgress = 0.72
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
        .sheet(isPresented: $showMoodTrends) {
            NavigationStack {
                MoodTrendsView(diaryManager: diaryManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showMoodTrends = false }
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
    }

    // MARK: - Background

    private var calendarBackground: some View {
        ZStack {
            // Base gradient (navy → deep purple)
            LinearGradient(
                colors: [
                    AppTheme.bg,
                    AppTheme.bg,
                    AppTheme.sidebarBg,
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
                    .foregroundStyle(AppTheme.primaryText)
                    .offset(x: monthNameOffset)
                    .opacity(monthNameOpacity)
                    .id("month-\(selectedMonth)-\(selectedYear)")
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(1)

                Text(String(selectedYear))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.accent.opacity(0.8))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(monthName) \(String(selectedYear))")

            Spacer()

            // Month navigation
            HStack(spacing: 4) {
                Button {
                    navigateMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedText)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(CalendarButtonStyle())
                .accessibilityLabel("Previous month")

                Button {
                    navigateMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedText)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(CalendarButtonStyle())
                .accessibilityLabel("Next month")
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
                                .foregroundStyle(isActive ? AppTheme.primaryText : AppTheme.sage)

                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(filter.color.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isActive ? filter.color.opacity(0.15) : AppTheme.subtle)
                                .overlay(
                                    Capsule()
                                        .stroke(isActive ? filter.color.opacity(0.3) : AppTheme.subtle, lineWidth: 1)
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
        let fullDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { idx, day in
                Text(day)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.dimText)
                    .frame(height: 20)
                    .accessibilityLabel(fullDays[idx])
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let daysInMonth = daysCount
        let firstDay = firstWeekday
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            // Empty leading cells (offset IDs to avoid collision with day numbers)
            ForEach(0..<firstDay, id: \.self) { index in
                Color.clear.frame(height: 52)
                    .id(-index - 1)
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
                    reduceMotion ? .none :
                    .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(cellIndex) * 0.015),
                    value: appeared
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Day \(day)\(isToday ? ", today" : "")\(emoji != nil ? ", mood: \(emoji!)" : "")")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens entries for this day")
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedDay = isSelected ? nil : day
                    }
                    // Only open day detail if there are entries for that day
                    if let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day)) {
                        let pages = diaryManager.getPages(for: date)
                        if !pages.isEmpty {
                            selectedDate = date
                            showDayEntries = true
                        }
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
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.dimText)
            }

            // Insight text — computed from real data
            insightText

            // Stats row — computed
            HStack(spacing: 16) {
                let stats = monthStats
                miniStat(value: "\(stats.daysLogged)", label: "Days logged", color: AppTheme.accent)
                miniStat(value: stats.daysInMonth > 0 ? "\(Int(Double(stats.daysLogged) / Double(stats.daysInMonth) * 100))%" : "0%", label: "Consistency", color: AppTheme.moodCalm)
                miniStat(value: formattedWordCount(stats.totalWords), label: "Words", color: AppTheme.gradientPurple)
            }
            .padding(.top, 4)

            // Trends button
            Button {
                showMoodTrends = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .semibold))
                    Text("View Mood Trends")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(CalendarButtonStyle())
            .padding(.top, 6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.subtle, AppTheme.subtle],
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
                .foregroundStyle(AppTheme.dimText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppTheme.subtle, lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: streakRingProgress)
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
                    Text("\(monthStats.currentStreak)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("days")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(monthStats.currentStreak) day streak")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: monthStats.currentStreak >= 3 ? "flame.fill" : "pencil.line")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xFDBA74), Color(hex: 0xF97316)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(monthStats.currentStreak >= 7 ? "You're on fire!" : monthStats.currentStreak >= 3 ? "Keep it going!" : monthStats.currentStreak > 0 ? "Building momentum" : "Start your streak")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text(monthStats.currentStreak > 0 ? "\(monthStats.currentStreak)-day writing streak. Every page is a gift to your future self." : "Write today to start building your streak.")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(AppTheme.mutedText)
                    .lineSpacing(3)
                    .lineLimit(3)
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
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color(hex: 0xC49340)],
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
                .foregroundStyle(AppTheme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(AppTheme.subtle)
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.subtle, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(CalendarButtonStyle())
        }
    }

    // MARK: - Navigation

    private func navigateMonth(by offset: Int) {
        monthDirection = offset

        // Slide month name out
        withAnimation(.easeIn(duration: 0.15)) {
            monthNameOffset = CGFloat(-offset) * 30
            monthNameOpacity = 0
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appeared = false
            cardsAppeared = false
            streakRingProgress = 0
        }

        var newMonth = selectedMonth + offset
        var newYear = selectedYear
        if newMonth > 12 { newMonth = 1; newYear += 1 }
        else if newMonth < 1 { newMonth = 12; newYear -= 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selectedMonth = newMonth
            selectedYear = newYear
            selectedDay = nil

            // Slide month name in from opposite side
            monthNameOffset = CGFloat(offset) * 30
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                monthNameOffset = 0
                monthNameOpacity = 1
            }

            Task { await loadMoods() }

            withAnimation(.easeOut(duration: 0.45).delay(0.05)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                cardsAppeared = true
            }
            withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                streakRingProgress = 0.72
            }
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
        // First check day moods (set via mood picker)
        if let moodData = monthlyMoods[selectedMonth], let emoji = moodData[day] {
            return emoji
        }
        // Then check page emojis (from the latest entry that day)
        if let pageData = monthlyPageEmojis[selectedMonth], let emoji = pageData[day] {
            return emoji
        }
        return nil
    }

    private func hasStreakConnection(day: Int) -> Bool {
        return effectiveEmoji(for: day) != nil && effectiveEmoji(for: day - 1) != nil
    }

    // MARK: - Month Stats (computed from real data)

    private struct MonthStatsData {
        var daysLogged: Int = 0
        var totalEntries: Int = 0
        var totalWords: Int = 0
        var currentStreak: Int = 0
        var daysInMonth: Int = 30
    }

    private var monthStats: MonthStatsData {
        guard let monthStart = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return MonthStatsData()
        }

        let pages = diaryManager.getPages(from: monthStart, to: monthEnd)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        // Count unique days with entries
        var daysWithEntries = Set<Int>()
        var totalWords = 0
        for page in pages {
            let day = calendar.component(.day, from: page.createdAt)
            daysWithEntries.insert(day)
            // Rough word count from plaintext content
            if let content = page.plaintextContent {
                let text = (try? NSAttributedString(data: content, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string)
                    ?? String(data: content, encoding: .utf8) ?? ""
                totalWords += text.split(separator: " ").count
            }
        }

        // Calculate current streak (consecutive days ending at today or latest entry)
        let today = calendar.component(.day, from: Date())
        let isCurrentMonth = calendar.component(.month, from: Date()) == selectedMonth && calendar.component(.year, from: Date()) == selectedYear
        let checkFrom = isCurrentMonth ? today : daysInMonth
        var streak = 0
        for d in stride(from: checkFrom, through: 1, by: -1) {
            if daysWithEntries.contains(d) {
                streak += 1
            } else {
                break
            }
        }

        return MonthStatsData(
            daysLogged: daysWithEntries.count,
            totalEntries: pages.count,
            totalWords: totalWords,
            currentStreak: streak,
            daysInMonth: daysInMonth
        )
    }

    @ViewBuilder
    private var insightText: some View {
        let stats = monthStats
        if stats.daysLogged > 0 {
            let daysStr = "\(stats.daysLogged) day\(stats.daysLogged == 1 ? "" : "s")"
            let entriesStr = "\(stats.totalEntries) entr\(stats.totalEntries == 1 ? "y" : "ies")"
            let wordsStr = formattedWordCount(stats.totalWords)

            let part1 = Text("You wrote on ").foregroundStyle(AppTheme.mutedText)
            let part2 = Text(daysStr).foregroundStyle(AppTheme.accent).bold()
            let part3 = Text(" this month with ").foregroundStyle(AppTheme.mutedText)
            let part4 = Text(entriesStr).foregroundStyle(AppTheme.accent).bold()
            let part5 = Text(" totaling about ").foregroundStyle(AppTheme.mutedText)
            let part6 = Text(wordsStr).foregroundStyle(AppTheme.gradientPurple).bold()
            let part7 = Text(".").foregroundStyle(AppTheme.mutedText)

            (part1 + part2 + part3 + part4 + part5 + part6 + part7)
                .font(.system(size: 14))
                .lineSpacing(6)
        } else {
            Text("No entries yet this month. Start writing to see your insights here.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
                .lineSpacing(6)
        }
    }

    private func formattedWordCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
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

        // Also load page emojis for the year
        await loadPageEmojis()
    }

    private func loadPageEmojis() async {
        var result: [Int: [Int: String]] = [:]
        // Get all pages for the selected year
        let yearStart = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date()
        let yearEnd = calendar.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? Date()

        let pages = diaryManager.getPages(from: yearStart, to: yearEnd)
        for page in pages {
            let m = calendar.component(.month, from: page.createdAt)
            let d = calendar.component(.day, from: page.createdAt)

            // Decrypt emojis for this page
            let emojis = await diaryManager.decryptPageEmojis(page)
            guard let firstEmoji = emojis.first, !firstEmoji.isEmpty else { continue }

            if result[m] == nil { result[m] = [:] }
            // Only set if no emoji yet for this day, or this page is newer (pages come sorted)
            if result[m]?[d] == nil {
                result[m]?[d] = firstEmoji
            }
        }
        monthlyPageEmojis = result
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
    @State private var todayPulse = false

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
                    .transition(.scale.combined(with: .opacity))
            }

            // Background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )

            // Content
            VStack(spacing: 1) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 16))

                    Text("\(day)")
                        .font(.system(size: 9, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? AppTheme.accent : AppTheme.mutedText)
                } else {
                    Text("\(day)")
                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? AppTheme.accent : AppTheme.mutedText.opacity(0.25))
                }

                // Today dot
                if isToday {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(todayPulse ? 0.3 : 0.0))
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 4, height: 4)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            todayPulse = true
                        }
                    }
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
            return AppTheme.subtle
        } else {
            return AppTheme.subtle
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
