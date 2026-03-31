import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class WritingGoalService {

    static let shared = WritingGoalService()
    private init() {}

    /// Counts total words written across all of today's pages.
    func getTodayWordCount(diaryManager: DiaryManager) async -> Int {
        let todayPages = diaryManager.getPages(for: Date())
        var totalWords = 0

        for page in todayPages {
            if let decrypted = await diaryManager.decryptPage(page) {
                // Count title words
                let titleWords = decrypted.title
                    .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                    .count

                // Count body words
                var bodyWords = 0
                if let contentData = decrypted.content,
                   let attr = try? NSAttributedString(
                    data: contentData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                   ) {
                    bodyWords = attr.string
                        .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                        .count
                }

                totalWords += titleWords + bodyWords
            }
        }

        return totalWords
    }

    /// Returns the current progress toward the daily writing goal.
    func getGoalProgress(diaryManager: DiaryManager, goal: Int) async -> (words: Int, goal: Int, percentage: Double) {
        let words = await getTodayWordCount(diaryManager: diaryManager)
        let pct = goal > 0 ? min(Double(words) / Double(goal), 1.0) : 0.0
        return (words: words, goal: goal, percentage: pct)
    }

    /// Returns word counts for the last 7 days.
    func getWeeklyProgress(diaryManager: DiaryManager, goal: Int) async -> [(date: Date, words: Int)] {
        let calendar = Calendar.current
        var results: [(date: Date, words: Int)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date())) else { continue }
            let pages = diaryManager.getPages(for: date)
            var dayWords = 0

            for page in pages {
                if let decrypted = await diaryManager.decryptPage(page) {
                    let titleWords = decrypted.title
                        .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                        .count
                    var bodyWords = 0
                    if let contentData = decrypted.content,
                       let attr = try? NSAttributedString(
                        data: contentData,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                       ) {
                        bodyWords = attr.string
                            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                            .count
                    }
                    dayWords += titleWords + bodyWords
                }
            }

            results.append((date: date, words: dayWords))
        }

        return results
    }
}
