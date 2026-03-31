import Foundation
import NaturalLanguage
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Mood Detection Service

@MainActor
final class MoodDetectionService {

    static let shared = MoodDetectionService()
    private init() {}

    // MARK: - Detect Mood from Text

    func detectMood(from text: String) -> (emoji: String, label: String, confidence: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 10 else { return nil }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed

        let (sentiment, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)

        guard let sentimentTag = sentiment else { return nil }
        let score = Double(sentimentTag.rawValue) ?? 0.0

        // Map sentiment score to mood
        let result: (emoji: String, label: String, confidence: Double)

        switch score {
        case let s where s > 0.5:
            result = (emoji: "😊", label: "Happy", confidence: min(abs(s), 1.0))
        case let s where s > 0.2:
            result = (emoji: "😌", label: "Content", confidence: min(abs(s), 1.0))
        case let s where s > -0.2:
            result = (emoji: "🤔", label: "Reflective", confidence: max(1.0 - abs(s) * 2, 0.3))
        case let s where s > -0.5:
            result = (emoji: "😔", label: "Melancholy", confidence: min(abs(s), 1.0))
        default:
            result = (emoji: "😢", label: "Sad", confidence: min(abs(score), 1.0))
        }

        return result
    }

    // MARK: - Suggest Mood for a Page

    func suggestMood(for page: Page, diaryManager: DiaryManager) async -> (emoji: String, label: String)? {
        guard let decrypted = await diaryManager.decryptPage(page) else { return nil }

        // Extract plain text from RTF content
        var text = decrypted.title

        if let contentData = decrypted.content {
            if let attr = try? NSAttributedString(
                data: contentData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                text += " " + attr.string
            } else if let plainText = String(data: contentData, encoding: .utf8) {
                text += " " + plainText
            }
        }

        guard let mood = detectMood(from: text) else { return nil }
        return (emoji: mood.emoji, label: mood.label)
    }
}
