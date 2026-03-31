import Foundation
import NaturalLanguage
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Weekly Reflection Model

struct WeeklyReflection: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let weekEndDate: Date
    let totalEntries: Int
    let totalWords: Int
    let dominantMood: (emoji: String, label: String)?
    let themes: [String]
    let moodArc: String
    let suggestion: String
    let reflectionText: String
}

// MARK: - Weekly Reflection Service

@MainActor
final class WeeklyReflectionService {

    // MARK: - Public API

    func generateWeeklyReflection(diaryManager: DiaryManager) async -> WeeklyReflection? {
        let calendar = Calendar.current
        let today = Date()

        // Calculate the week range (Monday-Sunday of last completed week)
        let weekEnd: Date
        let weekStart: Date

        // Find last Sunday (end of last week)
        let currentWeekday = calendar.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ...
        let daysBackToSunday = (currentWeekday == 1) ? 0 : (currentWeekday - 1)
        weekEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysBackToSunday, to: today) ?? today)
        weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd

        // Gather all entries for the week
        var allDecrypted: [(page: Page, title: String, body: String, date: Date, emojis: [String])] = []

        for dayOffset in 0...6 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let pages = diaryManager.getPages(for: date)
            for page in pages {
                if let decrypted = await diaryManager.decryptPage(page) {
                    let plainText = extractPlainText(from: decrypted.content)
                    allDecrypted.append((
                        page: page,
                        title: decrypted.title,
                        body: plainText,
                        date: page.date,
                        emojis: decrypted.emojis
                    ))
                }
            }
        }

        guard !allDecrypted.isEmpty else { return nil }

        // Compute stats
        let totalEntries = allDecrypted.count
        let allBodies = allDecrypted.map(\.body)
        let totalWords = allBodies.reduce(0) { $0 + wordCount($1) }

        // Extract themes
        let themes = extractThemes(from: allBodies)

        // Determine dominant mood from emojis
        let dominantMood = determineDominantMood(from: allDecrypted.flatMap(\.emojis))

        // Compute mood arc using sentiment
        let moodArc = computeMoodArc(entries: allDecrypted)

        // Generate suggestion
        let suggestion = generateSuggestion(
            entries: allDecrypted,
            totalWords: totalWords,
            themes: themes
        )

        // Build reflection text
        let reflectionText = buildReflectionText(
            totalEntries: totalEntries,
            totalWords: totalWords,
            themes: themes,
            moodArc: moodArc,
            dominantMood: dominantMood
        )

        return WeeklyReflection(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            totalEntries: totalEntries,
            totalWords: totalWords,
            dominantMood: dominantMood,
            themes: themes,
            moodArc: moodArc,
            suggestion: suggestion,
            reflectionText: reflectionText
        )
    }

    /// Check if today is Monday (auto-trigger day)
    func shouldAutoShow() -> Bool {
        Calendar.current.component(.weekday, from: Date()) == 2 // Monday
    }

    /// Check if the user has already seen the weekly reflection this week
    func hasSeenThisWeek() -> Bool {
        guard let lastSeen = UserDefaults.standard.object(forKey: "weeklyReflectionLastSeen") as? Date else {
            return false
        }
        return Calendar.current.isDate(lastSeen, equalTo: Date(), toGranularity: .weekOfYear)
    }

    func markAsSeen() {
        UserDefaults.standard.set(Date(), forKey: "weeklyReflectionLastSeen")
    }

    // MARK: - Theme Extraction

    private func extractThemes(from texts: [String]) -> [String] {
        let combined = texts.joined(separator: ". ")
        guard !combined.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = combined

        var nounCounts: [String: Int] = [:]
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]

        tagger.enumerateTags(in: combined.startIndex..<combined.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, range in
            if let tag = tag, tag == .noun {
                let word = String(combined[range]).lowercased()
                // Filter out short/common words
                if word.count > 3 && !Self.stopWords.contains(word) {
                    nounCounts[word, default: 0] += 1
                }
            }
            return true
        }

        // Also try name type for proper nouns / named entities
        let nameTagger = NLTagger(tagSchemes: [.nameType])
        nameTagger.string = combined
        nameTagger.enumerateTags(in: combined.startIndex..<combined.endIndex,
                                  unit: .word,
                                  scheme: .nameType,
                                  options: options) { tag, range in
            if let tag = tag, (tag == .personalName || tag == .placeName || tag == .organizationName) {
                let word = String(combined[range])
                if word.count > 2 {
                    nounCounts[word.lowercased(), default: 0] += 2 // Boost named entities
                }
            }
            return true
        }

        // Return top themes, capitalized
        let sorted = nounCounts.sorted { $0.value > $1.value }
        return Array(sorted.prefix(6).map { $0.key.capitalized })
    }

    // MARK: - Mood Detection

    private func determineDominantMood(from emojis: [String]) -> (emoji: String, label: String)? {
        guard !emojis.isEmpty else { return nil }

        var emojiCounts: [String: Int] = [:]
        for emoji in emojis {
            emojiCounts[emoji, default: 0] += 1
        }

        guard let top = emojiCounts.max(by: { $0.value < $1.value }) else { return nil }

        let label = Self.emojiLabels[top.key] ?? "Expressive"
        return (emoji: top.key, label: label)
    }

    // MARK: - Mood Arc (Sentiment Analysis)

    private func computeMoodArc(entries: [(page: Page, title: String, body: String, date: Date, emojis: [String])]) -> String {
        guard entries.count >= 2 else {
            return "A single moment of reflection this week."
        }

        let sorted = entries.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        let firstHalf = sorted[0..<midpoint]
        let secondHalf = sorted[midpoint...]

        let firstSentiment = averageSentiment(for: Array(firstHalf).map(\.body))
        let secondSentiment = averageSentiment(for: Array(secondHalf).map(\.body))

        let firstLabel = sentimentLabel(firstSentiment)
        let secondLabel = sentimentLabel(secondSentiment)

        if firstLabel == secondLabel {
            return "A consistently \(firstLabel.lowercased()) week throughout."
        } else {
            return "Started \(firstLabel.lowercased()), ended \(secondLabel.lowercased())."
        }
    }

    private func averageSentiment(for texts: [String]) -> Double {
        guard !texts.isEmpty else { return 0.0 }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        var total = 0.0

        for text in texts {
            tagger.string = text
            if let tag = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0,
               let score = Double(tag.rawValue) {
                total += score
            }
        }

        return total / Double(texts.count)
    }

    private func sentimentLabel(_ score: Double) -> String {
        switch score {
        case 0.3...: return "Uplifted"
        case 0.1..<0.3: return "Hopeful"
        case -0.1..<0.1: return "Balanced"
        case -0.3..<(-0.1): return "Contemplative"
        default: return "Introspective"
        }
    }

    // MARK: - Suggestion

    private func generateSuggestion(
        entries: [(page: Page, title: String, body: String, date: Date, emojis: [String])],
        totalWords: Int,
        themes: [String]
    ) -> String {
        let calendar = Calendar.current

        // Check writing time patterns
        let hours = entries.map { calendar.component(.hour, from: $0.date) }
        let avgHour = hours.isEmpty ? 12 : hours.reduce(0, +) / hours.count

        // Check entry count patterns
        let dayOfWeekCounts = Dictionary(grouping: entries) { calendar.component(.weekday, from: $0.date) }
        let busiestDay = dayOfWeekCounts.max(by: { $0.value.count < $1.value.count })

        let suggestions: [String]

        if avgHour >= 20 {
            suggestions = [
                "You wrote mostly in the evenings -- keep that night-owl rhythm going.",
                "Your late-night reflections carry a special depth. Protect that quiet time."
            ]
        } else if avgHour < 10 {
            suggestions = [
                "Morning pages suit you. That fresh perspective shines through your words.",
                "Writing early sets the tone for your whole day. Beautiful habit."
            ]
        } else if totalWords < 100 {
            suggestions = [
                "Even a few words matter. Try setting a small goal -- just three sentences a day.",
                "Short entries are still entries. Every word is a gift to your future self."
            ]
        } else if entries.count >= 7 {
            suggestions = [
                "You wrote every single day this week. That consistency is rare and powerful.",
                "A full week of writing. You are building something meaningful, one page at a time."
            ]
        } else if let busiest = busiestDay {
            let dayName = calendar.weekdaySymbols[busiest.key - 1]
            suggestions = [
                "\(dayName) seems to be your most inspired day. Lean into that energy.",
                "You tend to write the most on \(dayName)s. There is something about that day that calls to you."
            ]
        } else {
            suggestions = [
                "Keep going. Your words are weaving a story only you can tell.",
                "Every page you write is a conversation with your future self."
            ]
        }

        return suggestions.randomElement() ?? suggestions[0]
    }

    // MARK: - Reflection Text

    private func buildReflectionText(
        totalEntries: Int,
        totalWords: Int,
        themes: [String],
        moodArc: String,
        dominantMood: (emoji: String, label: String)?
    ) -> String {
        var parts: [String] = []

        parts.append("This week you wrote \(totalEntries) \(totalEntries == 1 ? "entry" : "entries") totaling \(totalWords) words.")

        if !themes.isEmpty {
            let themeList = themes.prefix(3).joined(separator: ", ")
            parts.append("Your thoughts revolved around \(themeList).")
        }

        if let mood = dominantMood {
            parts.append("The dominant feeling was \(mood.label.lowercased()) \(mood.emoji).")
        }

        parts.append(moodArc)

        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func extractPlainText(from data: Data?) -> String {
        guard let data = data else { return "" }
        #if canImport(UIKit)
        if let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            return attr.string
        }
        #endif
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Constants

    private static let stopWords: Set<String> = [
        "that", "this", "with", "from", "have", "been", "were", "they",
        "their", "what", "when", "which", "will", "about", "would",
        "there", "could", "other", "some", "than", "then", "them",
        "these", "into", "just", "like", "more", "also", "very",
        "much", "most", "really", "thing", "things", "today", "still",
        "back", "good", "time", "make", "know", "think", "want",
        "going", "well", "even", "only", "after", "before"
    ]

    private static let emojiLabels: [String: String] = [
        "😊": "Happy", "😄": "Joyful", "😌": "Peaceful", "🥰": "Loving",
        "😢": "Sad", "😔": "Melancholy", "😤": "Frustrated", "😡": "Angry",
        "😰": "Anxious", "🤔": "Thoughtful", "😴": "Tired", "🥳": "Celebratory",
        "🌙": "Reflective", "🌿": "Calm", "🌀": "Restless", "✨": "Inspired",
        "🦋": "Transforming", "🍏": "Fresh", "💭": "Dreamy", "☕️": "Cozy",
        "🌊": "Flowing", "🔥": "Passionate", "💫": "Magical", "🌸": "Gentle",
        "📖": "Studious", "🎨": "Creative", "🌲": "Grounded", "💤": "Restful",
        "🍋": "Energetic", "📚": "Curious", "🕯️": "Contemplative", "🍂": "Nostalgic",
    ]
}
