import Foundation

// MARK: - Widget Data Model

struct WidgetData: Codable {
    var currentStreak: Int
    var todayWordCount: Int
    var todayMood: String?
    var lastEntryTitle: String?
    var lastEntryDate: Date?
    var dailyGoal: Int
    var promptText: String?

    static let empty = WidgetData(
        currentStreak: 0,
        todayWordCount: 0,
        todayMood: nil,
        lastEntryTitle: nil,
        lastEntryDate: nil,
        dailyGoal: 200,
        promptText: nil
    )
}

// MARK: - Widget Data Provider

enum WidgetDataProvider {

    private static let suiteName = "group.com.ullam.shared"
    private static let dataKey = "widgetData"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Save widget data to the shared App Group UserDefaults.
    static func save(_ data: WidgetData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: dataKey)
        }
    }

    /// Load widget data from the shared App Group UserDefaults, returning defaults if unavailable.
    static func load() -> WidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty
        }
        return decoded
    }
}
