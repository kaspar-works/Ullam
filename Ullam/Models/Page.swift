import Foundation
import SwiftData

@Model
final class Page {
    var id: UUID = UUID()
    var diary: Diary?

    var date: Date = Date()

    // Content - stored encrypted for protected diaries
    var encryptedContent: Data?
    var plaintextContent: Data?

    var encryptedTitle: Data?
    var plaintextTitle: String?

    var encryptedSubtitle: Data?
    var plaintextSubtitle: String?

    // Emojis (max 3) - stored encrypted for protected diaries
    var encryptedEmojis: Data?
    var plaintextEmojis: [String]?

    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.page)
    var mediaAttachments: [MediaAttachment]?

    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var title: String {
        get { plaintextTitle ?? "" }
        set { plaintextTitle = newValue }
    }

    var subtitle: String? {
        get { plaintextSubtitle }
        set { plaintextSubtitle = newValue }
    }

    var emojis: [String] {
        get { plaintextEmojis ?? [] }
        set { plaintextEmojis = newValue }
    }

    init(diary: Diary, date: Date = Date()) {
        self.id = UUID()
        self.diary = diary
        self.date = date
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.plaintextEmojis = []
        self.mediaAttachments = []
    }
}
