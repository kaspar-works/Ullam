import Foundation

/// Calculates writing streaks from diary page data.
final class StreakTracker {

    /// Returns the current consecutive-day streak, longest streak ever, and total days with at least one entry.
    /// - Parameter pages: All pages for the current diary (any date range).
    /// - Returns: A tuple of `(currentStreak, longestStreak, totalDaysWritten)`.
    static func calculateStreak(pages: [Page]) -> (currentStreak: Int, longestStreak: Int, totalDaysWritten: Int) {
        guard !pages.isEmpty else {
            return (currentStreak: 0, longestStreak: 0, totalDaysWritten: 0)
        }

        let calendar = Calendar.current

        // Collect unique days (start-of-day) that have at least one page.
        let uniqueDays: Set<Date> = Set(pages.map { calendar.startOfDay(for: $0.date) })
        let sortedDays = uniqueDays.sorted(by: >)  // most recent first

        let totalDaysWritten = sortedDays.count

        // Walk backwards from today to compute the current streak.
        let today = calendar.startOfDay(for: Date())
        var currentStreak = 0
        var checkDate = today

        // Allow the streak to start from today or yesterday (in case no entry yet today).
        if uniqueDays.contains(today) {
            currentStreak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        } else {
            // No entry today — streak can still be live if yesterday has one.
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if uniqueDays.contains(yesterday) {
                currentStreak = 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: yesterday)!
            } else {
                // No entry today or yesterday — current streak is 0.
                // Still compute longest streak below.
                currentStreak = 0
                checkDate = today // won't enter loop
            }
        }

        // Continue counting consecutive days before checkDate.
        if currentStreak > 0 {
            while uniqueDays.contains(checkDate) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
        }

        // Compute the longest streak by walking sorted days (ascending).
        let ascending = sortedDays.reversed()  // oldest first
        var longestStreak = 0
        var runLength = 0
        var previousDay: Date?

        for day in ascending {
            if let prev = previousDay {
                let expected = calendar.date(byAdding: .day, value: 1, to: prev)!
                if calendar.isDate(day, inSameDayAs: expected) {
                    runLength += 1
                } else {
                    runLength = 1
                }
            } else {
                runLength = 1
            }
            longestStreak = max(longestStreak, runLength)
            previousDay = day
        }

        return (currentStreak: currentStreak, longestStreak: longestStreak, totalDaysWritten: totalDaysWritten)
    }
}
