#if os(iOS)
import SwiftUI

struct MoodTrendsView: View {
    @Bindable var diaryManager: DiaryManager

    @State private var stats: MoodStats = .empty
    @State private var moodDistribution: [(emoji: String, count: Int, percentage: Double)] = []
    @State private var writingTimeDistribution: [Int: Int] = [:]
    @State private var bestWritingDay: String?
    @State private var weeklyWordCounts: [Int] = Array(repeating: 0, count: 7)
    @State private var isLoaded = false
    @State private var cardsAppeared = false

    private let analyticsService = MoodAnalyticsService.shared

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Mood trend indicator
                trendCard
                    .padding(.horizontal, 16)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: cardsAppeared)

                // Mood distribution bars
                moodDistributionCard
                    .padding(.horizontal, 16)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: cardsAppeared)

                // Writing heatmap
                writingHeatmapCard
                    .padding(.horizontal, 16)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: cardsAppeared)

                // Weekly word count
                weeklyWordCountCard
                    .padding(.horizontal, 16)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: cardsAppeared)

                // Insight cards
                insightsSection
                    .padding(.horizontal, 16)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: cardsAppeared)

                Spacer(minLength: 80)
            }
        }
        .background(trendsBackground)
        .task {
            await loadData()
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                cardsAppeared = true
            }
        }
    }

    // MARK: - Background

    private var trendsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.bg, AppTheme.bg, AppTheme.sidebarBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppTheme.accent.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 350
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppTheme.gradientPink.opacity(0.04), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mood Trends")
                .font(.custom("NewYork-Bold", size: 32, relativeTo: .largeTitle))
                .foregroundStyle(AppTheme.primaryText)

            Text("YOUR EMOTIONAL LANDSCAPE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(AppTheme.accent.opacity(0.7))
        }
    }

    // MARK: - Trend Card

    private var trendCard: some View {
        HStack(spacing: 16) {
            // Trend arrow
            ZStack {
                Circle()
                    .fill(trendColor.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: trendIcon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(trendColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mood Trend")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)

                Text(trendLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.totalEntriesThisWeek)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Text("entries this week")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
            }
        }
        .padding(18)
        .background(glassCard)
    }

    private var trendColor: Color {
        switch stats.moodTrend {
        case .improving: return Color(hex: 0x34D399)
        case .stable: return AppTheme.accent
        case .declining: return Color(hex: 0xF87171)
        }
    }

    private var trendIcon: String {
        switch stats.moodTrend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    private var trendLabel: String {
        switch stats.moodTrend {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    // MARK: - Mood Distribution

    private var moodDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("Mood Distribution")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("Last 30 days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
            }

            if moodDistribution.isEmpty {
                Text("No mood data yet. Set your daily mood to see trends.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.dimText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(moodDistribution.prefix(6).enumerated()), id: \.offset) { index, item in
                        moodBarRow(
                            emoji: item.emoji,
                            count: item.count,
                            percentage: item.percentage,
                            delay: Double(index) * 0.08
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(glassCard)
    }

    private func moodBarRow(emoji: String, count: Int, percentage: Double, delay: Double) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 32)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.subtle)
                        .frame(height: 24)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.gradientBlue, AppTheme.gradientPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: cardsAppeared ? geo.size.width * CGFloat(percentage / 100.0) : 0, height: 24)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(delay), value: cardsAppeared)
                }
            }
            .frame(height: 24)

            Text("\(Int(percentage))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedText)
                .frame(width: 38, alignment: .trailing)
        }
    }

    // MARK: - Writing Heatmap

    private var writingHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.gradientPink)
                Text("Writing Heatmap")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("Last 30 days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
            }

            // Hour labels on top (every 4th hour)
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 32)
                ForEach([0, 4, 8, 12, 16, 20], id: \.self) { hour in
                    Text(hourLabel(hour))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(AppTheme.dimText)
                        .frame(maxWidth: .infinity)
                }
            }

            // 7 rows (days of week) x 24 columns (hours)
            let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            VStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    HStack(spacing: 0) {
                        Text(dayLabels[dayIndex])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.dimText)
                            .frame(width: 32, alignment: .leading)

                        // 24 hour dots grouped into 6 blocks of 4
                        HStack(spacing: 2) {
                            ForEach(0..<24, id: \.self) { hour in
                                let count = writingTimeDistribution[hour] ?? 0
                                let maxCount = max(writingTimeDistribution.values.max() ?? 1, 1)
                                let intensity = Double(count) / Double(maxCount)

                                Circle()
                                    .fill(heatmapColor(intensity: intensity))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.dimText)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(intensity: intensity))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.dimText)
            }
        }
        .padding(18)
        .background(glassCard)
    }

    private func heatmapColor(intensity: Double) -> Color {
        if intensity == 0 { return AppTheme.subtle }
        return AppTheme.accent.opacity(0.15 + intensity * 0.7)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    // MARK: - Weekly Word Count

    private var weeklyWordCountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x34D399))
                Text("Weekly Words")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("\(stats.totalWordsThisWeek) total")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
            }

            let maxWords = max(weeklyWordCounts.max() ?? 1, 1)
            let dayLabels = recentDayLabels()

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 6) {
                        // Word count label
                        if weeklyWordCounts[index] > 0 {
                            Text("\(weeklyWordCounts[index])")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.dimText)
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x34D399).opacity(0.4), Color(hex: 0x34D399).opacity(0.8)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                height: cardsAppeared
                                    ? max(CGFloat(weeklyWordCounts[index]) / CGFloat(maxWords) * 80, 4)
                                    : 4
                            )
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.06 + 0.3),
                                value: cardsAppeared
                            )

                        // Day label
                        Text(dayLabels[index])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.dimText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding(18)
        .background(glassCard)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.gradientPink)
                Text("Insights")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }
            .padding(.bottom, 4)

            // Best writing day
            if let bestDay = bestWritingDay {
                insightPill(
                    icon: "calendar.badge.checkmark",
                    text: "Your most active day is \(bestDay)",
                    color: AppTheme.moodHappy
                )
            }

            // Peak writing time
            if let peakHour = writingTimeDistribution.max(by: { $0.value < $1.value })?.key {
                insightPill(
                    icon: "clock.fill",
                    text: "You write most at \(formattedHour(peakHour))",
                    color: AppTheme.moodCalm
                )
            }

            // Average words
            if stats.averageWordsPerDay > 0 {
                insightPill(
                    icon: "text.alignleft",
                    text: "Average \(stats.averageWordsPerDay) words/day",
                    color: Color(hex: 0x34D399)
                )
            }

            // Most frequent mood
            if let mood = stats.mostFrequentMood {
                insightPill(
                    icon: "heart.fill",
                    text: "Your most common mood: \(mood)",
                    color: AppTheme.moodLove
                )
            }
        }
    }

    private func insightPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )
        )
    }

    private func formattedHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(hour: hour)) else { return "\(hour)" }
        return formatter.string(from: date).lowercased()
    }

    // MARK: - Glass Card Modifier

    private var glassCard: some View {
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
    }

    // MARK: - Data Loading

    private func loadData() async {
        stats = await analyticsService.calculateWeeklyStats(diaryManager: diaryManager)
        moodDistribution = await analyticsService.getMoodDistribution(diaryManager: diaryManager, days: 30)
        writingTimeDistribution = analyticsService.getWritingTimeDistribution(diaryManager: diaryManager)
        bestWritingDay = analyticsService.getBestWritingDay(diaryManager: diaryManager)
        weeklyWordCounts = await loadWeeklyWordCounts()
        isLoaded = true
    }

    private func loadWeeklyWordCounts() async -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var counts: [Int] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                counts.append(0)
                continue
            }
            let pages = diaryManager.getPages(for: date)
            var dayWords = 0
            for page in pages {
                if let decrypted = await diaryManager.decryptPage(page),
                   let contentData = decrypted.content {
                    if let attr = try? NSAttributedString(
                        data: contentData,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    ) {
                        dayWords += attr.string.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
                    }
                }
            }
            counts.append(dayWords)
        }
        return counts
    }

    private func recentDayLabels() -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        return (0..<7).reversed().map { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return "" }
            return formatter.string(from: date)
        }
    }
}

#endif // os(iOS)
