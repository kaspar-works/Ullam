import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Conversation Message

struct ConversationMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let relatedEntryDate: Date?

    init(text: String, isUser: Bool, relatedEntryDate: Date? = nil) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.relatedEntryDate = relatedEntryDate
    }
}

// MARK: - Past Self Service

@MainActor
final class PastSelfService {

    // MARK: - Find Relevant Entries

    func findRelevantEntries(
        query: String,
        diaryManager: DiaryManager
    ) async -> [(page: Page, title: String, body: String, date: Date)] {
        let allPages = diaryManager.getAllPages()
        let queryWords = extractKeywords(from: query)

        guard !queryWords.isEmpty else { return [] }

        var scored: [(page: Page, title: String, body: String, date: Date, score: Int)] = []

        for page in allPages {
            guard let decrypted = await diaryManager.decryptPage(page) else { continue }

            let plainText = extractPlainText(from: decrypted.content)
            guard !plainText.isEmpty else { continue }

            let titleLower = decrypted.title.lowercased()
            let bodyLower = plainText.lowercased()

            var score = 0

            for word in queryWords {
                // Title matches are worth more
                if titleLower.contains(word) {
                    score += 3
                }
                // Body matches
                let occurrences = bodyLower.components(separatedBy: word).count - 1
                score += occurrences
            }

            // Check for temporal queries
            if let targetDate = parseDateHint(from: query) {
                let calendar = Calendar.current
                if calendar.isDate(page.date, equalTo: targetDate, toGranularity: .month) {
                    score += 5
                }
                if calendar.isDate(page.date, equalTo: targetDate, toGranularity: .year) {
                    score += 2
                }
            }

            // Check for mood/feeling queries
            let feelingWords = ["feeling", "felt", "feel", "mood", "emotion", "happy", "sad", "anxious", "calm", "angry", "grateful", "worry", "worried", "love", "afraid", "excited", "tired"]
            let queryLower = query.lowercased()
            for feeling in feelingWords {
                if queryLower.contains(feeling) && bodyLower.contains(feeling) {
                    score += 2
                }
            }

            if score > 0 {
                scored.append((page: page, title: decrypted.title, body: plainText, date: page.date, score: score))
            }
        }

        // Sort by relevance, return top 5
        let sorted = scored.sorted { $0.score > $1.score }
        return Array(sorted.prefix(5).map { (page: $0.page, title: $0.title, body: $0.body, date: $0.date) })
    }

    // MARK: - Generate Response

    func generateResponse(
        query: String,
        entries: [(title: String, body: String, date: Date)]
    ) -> String {
        guard !entries.isEmpty else {
            return emptyResponse(for: query)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .long

        var parts: [String] = []

        // Opening line
        if entries.count == 1 {
            parts.append("I found something you wrote that might be relevant.")
        } else {
            parts.append("I found \(entries.count) moments from your past that connect to this.")
        }

        parts.append("")

        // Build excerpts
        for (index, entry) in entries.prefix(3).enumerated() {
            let dateStr = formatter.string(from: entry.date)
            let excerpt = extractRelevantExcerpt(from: entry.body, query: query)
            let titlePart = entry.title.isEmpty ? "" : " in \"\(entry.title)\""

            if index == 0 {
                parts.append("On \(dateStr)\(titlePart), you wrote:")
            } else {
                let connectors = ["Then, on", "And on", "Later, on", "Also on"]
                let connector = connectors[min(index, connectors.count - 1)]
                parts.append("\(connector) \(dateStr)\(titlePart), you wrote:")
            }
            parts.append("\"\(excerpt)\"")
            parts.append("")
        }

        // Closing narrative
        if entries.count > 1 {
            let daysBetween = daysBetweenFirstAndLast(entries.map(\.date))
            if daysBetween > 30 {
                parts.append("These reflections span \(daysBetween) days. Your thoughts on this have been with you for a while.")
            } else {
                parts.append("These moments are close together -- this was clearly on your mind.")
            }
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Suggested Questions

    static let suggestedQuestions: [String] = [
        "How was I feeling last month?",
        "What was I grateful for?",
        "What worried me recently?",
        "What made me happy this year?",
        "What did I dream about?",
        "When was I most creative?",
        "What was I working on?",
        "When did I feel most at peace?",
    ]

    // MARK: - Private Helpers

    private func extractKeywords(from query: String) -> [String] {
        let stopWords: Set<String> = [
            "i", "me", "my", "was", "is", "am", "are", "the", "a", "an",
            "what", "when", "where", "how", "did", "do", "does", "have",
            "has", "had", "about", "for", "with", "this", "that", "from",
            "been", "being", "were", "most", "last", "past", "recently",
        ]

        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }

        return Array(Set(words))
    }

    private func extractRelevantExcerpt(from body: String, query: String) -> String {
        let keywords = extractKeywords(from: query)
        let sentences = body.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Find the sentence with the most keyword matches
        var bestSentence = ""
        var bestScore = 0

        for sentence in sentences {
            let lower = sentence.lowercased()
            var score = 0
            for keyword in keywords {
                if lower.contains(keyword) { score += 1 }
            }
            if score > bestScore {
                bestScore = score
                bestSentence = sentence
            }
        }

        // If no keyword match, take the first meaningful sentence
        if bestSentence.isEmpty {
            bestSentence = sentences.first(where: { $0.count > 20 }) ?? sentences.first ?? body
        }

        // Trim to reasonable length
        if bestSentence.count > 200 {
            let endIndex = bestSentence.index(bestSentence.startIndex, offsetBy: 200)
            bestSentence = String(bestSentence[..<endIndex]) + "..."
        }

        return bestSentence
    }

    private func emptyResponse(for query: String) -> String {
        let responses = [
            "I searched through your pages, but I could not find anything about that. Perhaps you have not written about it yet -- today could be the day.",
            "Your past self does not seem to have written about this. Every unwritten thought is an invitation to reflect.",
            "Nothing in your diary matches this yet. Some stories are still waiting to be told.",
        ]
        return responses.randomElement() ?? responses[0]
    }

    private func daysBetweenFirstAndLast(_ dates: [Date]) -> Int {
        guard let earliest = dates.min(), let latest = dates.max() else { return 0 }
        return Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 0
    }

    private func parseDateHint(from query: String) -> Date? {
        let lower = query.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // "last month"
        if lower.contains("last month") {
            return calendar.date(byAdding: .month, value: -1, to: now)
        }

        // "last year"
        if lower.contains("last year") {
            return calendar.date(byAdding: .year, value: -1, to: now)
        }

        // Month names: "in march", "last march", etc.
        let months = ["january", "february", "march", "april", "may", "june",
                       "july", "august", "september", "october", "november", "december"]
        for (index, month) in months.enumerated() {
            if lower.contains(month) {
                var components = DateComponents()
                components.month = index + 1
                components.year = calendar.component(.year, from: now)
                // If the month hasn't happened yet this year, use last year
                if index + 1 > calendar.component(.month, from: now) {
                    components.year = (components.year ?? 0) - 1
                }
                return calendar.date(from: components)
            }
        }

        // "this week"
        if lower.contains("this week") {
            return calendar.date(byAdding: .day, value: -3, to: now)
        }

        // "yesterday"
        if lower.contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: now)
        }

        return nil
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
}
