import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "accent" // color key from AppTheme
    var diary: Diary?

    // Many-to-many via explicit join since SwiftData doesn't support it natively
    var pageIds: [UUID] = []

    var createdAt: Date = Date()

    init(name: String, color: String = "accent", diary: Diary? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.diary = diary
        self.pageIds = []
        self.createdAt = Date()
    }
}
