import Foundation
import SwiftData

@MainActor
final class WritingPromptService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Seed

    func seedPromptsIfNeeded() {
        let descriptor = FetchDescriptor<WritingPrompt>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for item in WritingPrompt.defaultPrompts {
            let prompt = WritingPrompt(text: item.text, category: item.category)
            modelContext.insert(prompt)
        }
        try? modelContext.save()
    }

    // MARK: - Daily Prompt

    func getDailyPrompt() -> WritingPrompt? {
        // Check if we already served a prompt today
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let usedTodayDescriptor = FetchDescriptor<WritingPrompt>(
            predicate: #Predicate<WritingPrompt> {
                $0.isUsed == true && $0.usedDate != nil && $0.usedDate! >= startOfDay && $0.usedDate! < endOfDay
            }
        )
        if let todayPrompt = try? modelContext.fetch(usedTodayDescriptor).first {
            return todayPrompt
        }

        // Get an unused prompt
        return pickNextUnused()
    }

    func refreshPrompt() -> WritingPrompt? {
        // Mark the current daily prompt so we skip it, then pick next
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let usedTodayDescriptor = FetchDescriptor<WritingPrompt>(
            predicate: #Predicate<WritingPrompt> {
                $0.isUsed == true && $0.usedDate != nil && $0.usedDate! >= startOfDay && $0.usedDate! < endOfDay
            }
        )
        // The current daily prompt stays marked as used; just pick a new unused one
        if let current = try? modelContext.fetch(usedTodayDescriptor).first {
            // Keep it marked used but clear today's date so it won't be returned as "today's"
            current.usedDate = Date.distantPast
        }

        return pickNextUnused()
    }

    func getPromptsByCategory(_ category: String) -> [WritingPrompt] {
        let descriptor = FetchDescriptor<WritingPrompt>(
            predicate: #Predicate<WritingPrompt> { $0.category == category }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Helpers

    private func pickNextUnused() -> WritingPrompt? {
        let descriptor = FetchDescriptor<WritingPrompt>(
            predicate: #Predicate<WritingPrompt> { $0.isUsed == false }
        )
        var unused = (try? modelContext.fetch(descriptor)) ?? []

        // If all used, reset them
        if unused.isEmpty {
            let allDescriptor = FetchDescriptor<WritingPrompt>()
            let all = (try? modelContext.fetch(allDescriptor)) ?? []
            for prompt in all {
                prompt.isUsed = false
                prompt.usedDate = nil
            }
            try? modelContext.save()
            unused = all
        }

        guard let picked = unused.randomElement() else { return nil }
        picked.isUsed = true
        picked.usedDate = Date()
        try? modelContext.save()
        return picked
    }
}
