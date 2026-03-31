import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Mood Stats

struct MoodStats {
    var weeklyMoodCounts: [String: Int]        // emoji -> count
    var mostFrequentMood: String?              // most common emoji
    var writingByHour: [Int: Int]              // hour (0-23) -> entry count
    var averageWordsPerDay: Int
    var moodTrend: MoodTrend
    var totalEntriesThisWeek: Int
    var totalWordsThisWeek: Int

    enum MoodTrend: String {
        case improving, stable, declining
    }

    static let empty = MoodStats(
        weeklyMoodCounts: [:],
        mostFrequentMood: nil,
        writingByHour: [:],
        averageWordsPerDay: 0,
        moodTrend: .stable,
        totalEntriesThisWeek: 0,
        totalWordsThisWeek: 0
    )
}

// MARK: - Mood Analytics Service

@MainActor
final class MoodAnalyticsService {

    static let shared = MoodAnalyticsService()
    private init() {}

    // MARK: - Weekly Stats

    func calculateWeeklyStats(diaryManager: DiaryManager) async -> MoodStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return .empty
        }

        // Gather pages for last 7 days
        var allPages: [Page] = []
        var moodCounts: [String: Int] = [:]
        var writingByHour: [Int: Int] = [:]
        var totalWords = 0
        var dailyWordCounts: [Int: Int] = [:] // day-of-week -> words

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let pages = diaryManager.getPages(for: date)
            allPages.append(contentsOf: pages)

            let weekday = calendar.component(.weekday, from: date)

            for page in pages {
                let hour = calendar.component(.hour, from: page.createdAt)
                writingByHour[hour, default: 0] += 1

                if let decrypted = await diaryManager.decryptPage(page) {
                    let wordCount = countWords(from: decrypted.content)
                    totalWords += wordCount
                    dailyWordCounts[weekday, default: 0] += wordCount
                }
            }

            // Get mood for this day
            if let mood = diaryManager.getDayMood(for: date),
               let emoji = await diaryManager.decryptDayMood(mood) {
                moodCounts[emoji, default: 0] += 1
            }
        }

        let activeDayOffsets: [Int] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return diaryManager.getPages(for: date).isEmpty ? nil : offset
        }
        let activeDays = max(Set(activeDayOffsets).count, 1)

        let mostFrequent = moodCounts.max(by: { $0.value < $1.value })?.key
        let trend = determineTrend(moodCounts: moodCounts, diaryManager: diaryManager)

        return MoodStats(
            weeklyMoodCounts: moodCounts,
            mostFrequentMood: mostFrequent,
            writingByHour: writingByHour,
            averageWordsPerDay: totalWords / activeDays,
            moodTrend: trend,
            totalEntriesThisWeek: allPages.count,
            totalWordsThisWeek: totalWords
        )
    }

    // MARK: - Monthly Stats

    func calculateMonthlyStats(diaryManager: DiaryManager, month: Int, year: Int) async -> MoodStats {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return .empty
        }

        var moodCounts: [String: Int] = [:]
        var writingByHour: [Int: Int] = [:]
        var totalWords = 0
        var totalEntries = 0
        var activeDays = 0

        for day in range {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            let pages = diaryManager.getPages(for: date)
            if !pages.isEmpty { activeDays += 1 }
            totalEntries += pages.count

            for page in pages {
                let hour = calendar.component(.hour, from: page.createdAt)
                writingByHour[hour, default: 0] += 1

                if let decrypted = await diaryManager.decryptPage(page) {
                    totalWords += countWords(from: decrypted.content)
                }
            }

            if let mood = diaryManager.getDayMood(for: date),
               let emoji = await diaryManager.decryptDayMood(mood) {
                moodCounts[emoji, default: 0] += 1
            }
        }

        let mostFrequent = moodCounts.max(by: { $0.value < $1.value })?.key
        let trend = determineTrend(moodCounts: moodCounts, diaryManager: diaryManager)

        return MoodStats(
            weeklyMoodCounts: moodCounts,
            mostFrequentMood: mostFrequent,
            writingByHour: writingByHour,
            averageWordsPerDay: totalWords / max(activeDays, 1),
            moodTrend: trend,
            totalEntriesThisWeek: totalEntries,
            totalWordsThisWeek: totalWords
        )
    }

    // MARK: - Mood Distribution

    func getMoodDistribution(diaryManager: DiaryManager, days: Int) async -> [(emoji: String, count: Int, percentage: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var moodCounts: [String: Int] = [:]

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            if let mood = diaryManager.getDayMood(for: date),
               let emoji = await diaryManager.decryptDayMood(mood) {
                moodCounts[emoji, default: 0] += 1
            }
        }

        let total = max(moodCounts.values.reduce(0, +), 1)
        return moodCounts
            .sorted { $0.value > $1.value }
            .map { (emoji: $0.key, count: $0.value, percentage: Double($0.value) / Double(total) * 100) }
    }

    // MARK: - Writing Time Distribution

    func getWritingTimeDistribution(diaryManager: DiaryManager) -> [Int: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var hourCounts: [Int: Int] = [:]

        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let pages = diaryManager.getPages(for: date)
            for page in pages {
                let hour = calendar.component(.hour, from: page.createdAt)
                hourCounts[hour, default: 0] += 1
            }
        }

        return hourCounts
    }

    // MARK: - Best Writing Day

    func getBestWritingDay(diaryManager: DiaryManager) -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weekdayCounts: [Int: Int] = [:]  // 1=Sunday .. 7=Saturday

        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let pages = diaryManager.getPages(for: date)
            if !pages.isEmpty {
                let weekday = calendar.component(.weekday, from: date)
                weekdayCounts[weekday, default: 0] += pages.count
            }
        }

        guard let bestWeekday = weekdayCounts.max(by: { $0.value < $1.value })?.key else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols[bestWeekday - 1]
    }

    // MARK: - Helpers

    private func countWords(from contentData: Data?) -> Int {
        guard let data = contentData else { return 0 }
        let text: String
        if let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            text = attr.string
        } else {
            text = String(data: data, encoding: .utf8) ?? ""
        }
        return text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func determineTrend(moodCounts: [String: Int], diaryManager: DiaryManager) -> MoodStats.MoodTrend {
        // Simple heuristic: positive emojis vs negative ones
        let positiveEmojis: Set<String> = ["😊", "😌", "🥰", "😄", "🌟", "✨", "🦋", "🌸", "💫", "🔥", "☀️", "🎨", "🌿", "💪", "🥳"]
        let negativeEmojis: Set<String> = ["😢", "😔", "😞", "😫", "😤", "😰", "🌀", "💧", "🥀"]

        var positiveCount = 0
        var negativeCount = 0

        for (emoji, count) in moodCounts {
            if positiveEmojis.contains(emoji) { positiveCount += count }
            else if negativeEmojis.contains(emoji) { negativeCount += count }
        }

        if positiveCount > negativeCount + 2 { return .improving }
        if negativeCount > positiveCount + 2 { return .declining }
        return .stable
    }
}
