import Foundation
import SwiftData

@Model
final class TimeCapsule {
    var id: UUID = UUID()
    var diary: Diary?

    // The message content (encrypted for protected diaries)
    var encryptedMessage: Data?
    var plaintextMessage: String?

    // When the capsule can be opened
    var unlockDate: Date = Date()
    var isOpened: Bool = false
    var openedDate: Date?

    var createdAt: Date = Date()

    var message: String {
        get { plaintextMessage ?? "" }
        set { plaintextMessage = newValue }
    }

    var isUnlocked: Bool {
        Date() >= unlockDate
    }

    init(diary: Diary, message: String, unlockDate: Date) {
        self.id = UUID()
        self.diary = diary
        self.plaintextMessage = message
        self.unlockDate = unlockDate
        self.isOpened = false
        self.createdAt = Date()
    }
}
