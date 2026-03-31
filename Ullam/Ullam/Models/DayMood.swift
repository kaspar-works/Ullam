import Foundation
import SwiftData

@Model
final class DayMood {
    var id: UUID = UUID()
    var diary: Diary?

    var date: Date = Date()

    // Single emoji for the day
    var encryptedEmoji: Data?
    var plaintextEmoji: String?

    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var emoji: String? {
        get { plaintextEmoji }
        set { plaintextEmoji = newValue }
    }

    init(diary: Diary, date: Date) {
        self.id = UUID()
        self.diary = diary
        self.date = Calendar.current.startOfDay(for: date)
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
