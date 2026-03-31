import Foundation
import WidgetKit

/// Bridges the main app data to widget extensions via shared UserDefaults.
@MainActor
enum WidgetBridge {

    /// Gathers current diary data and pushes it to the widget data store.
    static func updateWidgetData(diaryManager: DiaryManager) async {
        let allPages = diaryManager.getAllPages()
        let streak = StreakTracker.calculateStreak(pages: allPages)

        let todayWordCount = await WritingGoalService.shared.getTodayWordCount(diaryManager: diaryManager)

        // Get today's mood
        var todayMood: String?
        if let dayMood = diaryManager.getDayMood(for: Date()) {
            todayMood = await diaryManager.decryptDayMood(dayMood)
        }

        // Get last entry info
        let recentPages = diaryManager.getRecentPages(days: 30)
        var lastEntryTitle: String?
        var lastEntryDate: Date?
        if let lastPage = recentPages.first {
            if let decrypted = await diaryManager.decryptPage(lastPage) {
                lastEntryTitle = decrypted.title.isEmpty ? nil : decrypted.title
            }
            lastEntryDate = lastPage.date
        }

        // Daily goal — default to 200 words
        let dailyGoal = 200

        // Get today's writing prompt text if available
        // Note: WritingPromptService requires a ModelContext; the prompt text
        // should be set by the caller if available. We leave it nil here.
        let promptText: String? = nil

        let widgetData = WidgetData(
            currentStreak: streak.currentStreak,
            todayWordCount: todayWordCount,
            todayMood: todayMood,
            lastEntryTitle: lastEntryTitle,
            lastEntryDate: lastEntryDate,
            dailyGoal: dailyGoal,
            promptText: promptText
        )

        WidgetDataProvider.save(widgetData)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
