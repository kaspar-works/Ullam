import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
final class SampleDataGenerator {

    static func seedIfNeeded(diaryManager: DiaryManager) {
        guard let diary = diaryManager.currentDiary else { return }

        // Only seed once — check if diary already has pages
        let existingPages = diaryManager.getPages(for: Date())
        let calendar = Calendar.current

        // Check a few dates — if we already have seeded data, skip
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let oldPages = diaryManager.getPages(for: threeDaysAgo)
        if !oldPages.isEmpty { return }

        // Only seed if diary has very few entries (fresh install)
        if diary.pages.count > 5 { return }

        Task {
            await generateSampleEntries(diaryManager: diaryManager)
        }
    }

    private static func generateSampleEntries(diaryManager: DiaryManager) async {
        let calendar = Calendar.current
        let today = Date()

        let entries: [(daysAgo: Int, hour: Int, minute: Int, title: String, body: String, emojis: [String], dayMood: String?)] = [
            // Today
            (0, 7, 15, "Morning Light Through the Window",
             "Woke up to golden light streaming across the bedroom floor. The dust particles floating in the beam looked like tiny galaxies. Made pour-over coffee and sat in the reading chair for twenty minutes before touching my phone. This is becoming my favorite ritual.",
             ["☀️", "☕️"], "😌"),

            (0, 14, 30, "Afternoon Walk by the River",
             "The water was unusually clear today. Could see smooth stones at the bottom, each one a different shade of gray and brown. A heron stood perfectly still on the far bank. We watched each other for what felt like five minutes. Neither of us blinked.",
             ["🌊", "🦅"], nil),

            // Yesterday
            (1, 8, 0, "The Smell of Rain on Concrete",
             "It rained before dawn. By the time I stepped outside, the streets were steaming. There's a word for this smell — petrichor. But the word doesn't capture it. It's the smell of the earth exhaling after holding its breath.",
             ["🌧️"], "🌿"),

            (1, 21, 45, "Late Night Reading",
             "Finished the last chapter of 'Norwegian Wood'. Murakami has this way of making loneliness feel like a warm blanket rather than an empty room. Couldn't sleep after. Made chamomile tea and listened to the radiator hum.",
             ["📖", "🌙"], nil),

            // 2 days ago
            (2, 6, 30, "Pre-Dawn Sketching",
             "Drew the view from the kitchen window before sunrise. The tree in the backyard looked like a charcoal drawing against the navy sky. Used the new B6 pencils. The softness of the graphite felt like writing on silk.",
             ["✏️", "🌅"], "✨"),

            (2, 12, 0, "Lunch with an Old Friend",
             "Met Sophia at the café on 5th. She's moving to Lisbon next month. We talked about how strange it is that the people who know us best are scattered across different time zones. She said distance doesn't dilute connection — it distills it.",
             ["💛", "🍽️"], nil),

            (2, 19, 0, "Cooking Experiment",
             "Tried making risotto from scratch for the first time. Stood at the stove stirring for forty minutes. There's something meditative about the patience it requires. The rice absorbs the broth slowly, gradually. Like how we absorb experiences.",
             ["🍚"], nil),

            // 3 days ago
            (3, 9, 15, "The Old Bookshop on Cedar Lane",
             "Found a first edition of 'The Little Prince' tucked between two cookbooks. The owner didn't know what he had. The pages smelled like vanilla and dust. Bought it without negotiating. Some things are worth more than their price.",
             ["📚", "✨"], "📖"),

            (3, 22, 0, "Midnight Breakthrough",
             "Finally solved the design problem that's been haunting me for weeks. The answer was simplicity — remove, don't add. Stripped away three layers of complexity and suddenly everything clicked. The best solutions feel obvious in retrospect.",
             ["💡", "🎉"], nil),

            // 4 days ago
            (4, 7, 45, "Fog in the Valley",
             "The entire valley was filled with fog this morning. Only the church steeple and the tops of the tallest oaks were visible. It felt like standing at the edge of a cloud. The world reduced to shapes and silence.",
             ["🌫️"], "🌙"),

            (4, 16, 30, "Piano Practice",
             "Working on Debussy's 'Clair de Lune' again. My fingers remember the first page but stumble on the second. Music is a conversation between muscle memory and intention. Today they disagreed more than usual, but there were moments of grace.",
             ["🎹", "🎵"], nil),

            // 5 days ago
            (5, 10, 0, "Letters Never Sent",
             "Found a box of letters I wrote but never mailed. To people I loved, to versions of myself I've outgrown. Reading them felt like archaeology — excavating layers of who I used to be. Some of the words still sting. Others make me proud.",
             ["💌"], "💭"),

            (5, 20, 15, "Stargazing from the Roof",
             "Clear sky tonight. Could see Orion's belt, the Big Dipper, and what I think was Jupiter. The city lights wash out most stars, but enough remain to remind you of the scale of things. My problems felt proportionally smaller.",
             ["⭐", "🌌"], nil),

            // 6 days ago
            (6, 8, 30, "The Market at Dawn",
             "Arrived at the farmer's market just as they were setting up. The flower vendor was arranging sunflowers in tin buckets. Bought tomatoes still warm from the greenhouse, bread with a crust that crackled when squeezed, and a jar of wildflower honey.",
             ["🌻", "🍅"], "🌸"),

            (6, 15, 0, "Rainy Afternoon",
             "Spent three hours at the window watching rain trace paths down the glass. Each drop finds its own route, merging with others, splitting apart, racing to the sill. There's no wrong path for a raindrop. Maybe there's a lesson there.",
             ["🌧️", "🪟"], nil),

            // 7 days ago
            (7, 11, 0, "The Museum of Small Things",
             "Visited that tiny museum downtown — the one with the collection of miniature rooms. Each one is a perfect replica of a real space at 1:12 scale. A Victorian library. A Japanese tea room. A 1950s diner. Entire worlds in boxes.",
             ["🏛️"], "🎨"),

            (7, 18, 30, "Cooking for One",
             "Made a single perfect omelette. Three eggs, a handful of herbs from the windowsill garden, a splash of cream. Ate it at the counter standing up, looking at the sunset through the kitchen window. Solitude isn't loneliness when you choose it.",
             ["🍳", "🌿"], nil),

            // 8 days ago
            (8, 6, 0, "First Light",
             "Set an alarm to catch the sunrise. The sky went from indigo to coral to gold in twenty minutes. No filter could capture it. Some experiences are meant to be absorbed, not recorded. But here I am, recording it anyway.",
             ["🌅"], "✨"),

            // 9 days ago
            (9, 13, 0, "The Quiet Library",
             "Found a corner in the reference section where no one goes. Spent four hours there with nothing but a notebook and a pen. No wifi, no notifications. Just thoughts arriving at their own pace, like guests at an unhurried dinner party.",
             ["📝", "🤫"], "📚"),

            // 10 days ago
            (10, 20, 0, "Night Walk",
             "Walked the long way home through the park. The lampposts made pools of amber light on the wet path. A fox crossed in front of me, paused, looked back over its shoulder, then disappeared into the hedgerow. We acknowledged each other as fellow night travelers.",
             ["🦊", "🌙", "🚶"], "🌙"),
        ]

        for entry in entries {
            guard let entryDate = calendar.date(byAdding: .day, value: -entry.daysAgo, to: today),
                  let pageDate = calendar.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: entryDate) else {
                continue
            }

            // Create page
            guard let page = diaryManager.createPage(for: pageDate) else { continue }
            // Manually set createdAt to the correct time
            page.createdAt = pageDate

            // Build RTF content
            let rtfContent = buildRTF(entry.body)

            // Save page
            await diaryManager.savePage(
                page,
                title: entry.title,
                subtitle: nil,
                content: rtfContent,
                emojis: entry.emojis
            )

            // Set day mood (only once per day)
            if let mood = entry.dayMood {
                await diaryManager.setDayMood(mood, for: entryDate)
            }
        }

        print("✅ Seeded \(entries.count) sample entries")
    }

    private static func buildRTF(_ text: String) -> Data? {
        #if canImport(UIKit)
        let font = UIFont.preferredFont(forTextStyle: .body)
        let color = UIColor.black.withAlphaComponent(0.8)
        #else
        let font = NSFont.preferredFont(forTextStyle: .body)
        let color = NSColor.black.withAlphaComponent(0.8)
        #endif

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributed = NSAttributedString(string: text, attributes: attributes)
        return try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}
