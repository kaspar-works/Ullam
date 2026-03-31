import SwiftUI
import WidgetKit

// MARK: - Widget Theme (standalone, mirrors AppTheme)

enum WidgetTheme {
    static let bg          = Color(widgetHex: 0x1F2433)     // Navy
    static let sidebarBg   = Color(widgetHex: 0x2F3A55)     // Accent Blue
    static let accent      = Color(widgetHex: 0xD4A24C)     // Gold
    static let gradientPink = Color(widgetHex: 0xD4A24C)    // Gold
    static let gradientBlue = Color(widgetHex: 0x2F3A55)    // Accent Blue
    static let mutedText   = Color(widgetHex: 0x8890A0)     // Muted
    static let subtle      = Color.white.opacity(0.06)
    static let dimText     = Color.white.opacity(0.4)
}

// MARK: - Color Hex Extension (widget-local)

extension Color {
    init(widgetHex hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Timeline Entries

struct StreakEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct MoodEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct GoalEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct PromptEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Timeline Providers

struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let data = WidgetDataProvider.load()
        completion(StreakEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let data = WidgetDataProvider.load()
        let entry = StreakEntry(date: .now, data: data)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct MoodTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodEntry {
        MoodEntry(date: .now, data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodEntry) -> Void) {
        let data = WidgetDataProvider.load()
        completion(MoodEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodEntry>) -> Void) {
        let data = WidgetDataProvider.load()
        let entry = MoodEntry(date: .now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct GoalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: .now, data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        let data = WidgetDataProvider.load()
        completion(GoalEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        let data = WidgetDataProvider.load()
        let entry = GoalEntry(date: .now, data: data)
        // Refresh more frequently for goal tracking
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct PromptTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: .now, data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        let data = WidgetDataProvider.load()
        completion(PromptEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        let data = WidgetDataProvider.load()
        let entry = PromptEntry(date: .now, data: data)
        // Refresh at next midnight for a new daily prompt
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Definitions

struct UllamStreakWidget: Widget {
    let kind: String = "UllamStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetView(data: entry.data)
                .containerBackground(WidgetTheme.bg, for: .widget)
        }
        .configurationDisplayName("Writing Streak")
        .description("Track your consecutive days of writing.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UllamMoodWidget: Widget {
    let kind: String = "UllamMoodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodTimelineProvider()) { entry in
            MoodWidgetView(data: entry.data)
                .containerBackground(WidgetTheme.bg, for: .widget)
        }
        .configurationDisplayName("Today's Mood")
        .description("See your mood at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UllamGoalWidget: Widget {
    let kind: String = "UllamGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoalTimelineProvider()) { entry in
            WritingGoalWidgetView(data: entry.data)
                .containerBackground(WidgetTheme.bg, for: .widget)
        }
        .configurationDisplayName("Writing Goal")
        .description("Track your daily word count progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UllamPromptWidget: Widget {
    let kind: String = "UllamPromptWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PromptTimelineProvider()) { entry in
            PromptWidgetView(data: entry.data)
                .containerBackground(WidgetTheme.bg, for: .widget)
        }
        .configurationDisplayName("Writing Prompt")
        .description("Get inspired with a daily writing prompt.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

struct UllamWidgetBundle: WidgetBundle {
    var body: some Widget {
        UllamStreakWidget()
        UllamMoodWidget()
        UllamGoalWidget()
        UllamPromptWidget()
    }
}
