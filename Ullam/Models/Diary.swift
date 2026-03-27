import Foundation
import SwiftData

enum StoragePreference: String, Codable {
    case local
    case iCloud
}

@Model
final class Diary {
    var id: UUID = UUID()

    // For unprotected diaries: stored in plaintext
    // For protected diaries: name is encrypted with diary's key
    var encryptedName: Data?
    var plaintextName: String?

    // Security fields (always plaintext for lookup)
    var pincodeHash: Data?
    var encryptionSalt: Data?
    var isProtected: Bool = false

    // Visibility - if true, diary appears in switch list
    var isVisibleOnSwitch: Bool = true

    // Storage preference for this diary
    var storagePreference: StoragePreference = StoragePreference.iCloud

    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Page.diary)
    var pages: [Page]?

    @Relationship(deleteRule: .cascade, inverse: \DayMood.diary)
    var dayMoods: [DayMood]?

    var name: String {
        get { plaintextName ?? "Unknown" }
        set { plaintextName = newValue }
    }

    init(name: String = "Me & Me", isProtected: Bool = false, isVisibleOnSwitch: Bool = true, storagePreference: StoragePreference = .iCloud) {
        self.id = UUID()
        self.plaintextName = name
        self.isProtected = isProtected
        self.isVisibleOnSwitch = isVisibleOnSwitch
        self.storagePreference = storagePreference
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.pages = []
        self.dayMoods = []
    }
}
