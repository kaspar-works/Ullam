import Foundation
import SwiftData

enum MediaType: String, Codable {
    case image
    case video
    case audio
}

@Model
final class MediaAttachment {
    @Attribute(.unique) var id: UUID
    var page: Page?

    var mediaType: MediaType
    var fileName: String
    var thumbnailFileName: String?

    var isEncrypted: Bool
    var orderIndex: Int
    var createdAt: Date

    init(page: Page, mediaType: MediaType, fileName: String, orderIndex: Int = 0) {
        self.id = UUID()
        self.page = page
        self.mediaType = mediaType
        self.fileName = fileName
        self.orderIndex = orderIndex
        self.isEncrypted = page.diary?.isProtected ?? false
        self.createdAt = Date()
    }
}
