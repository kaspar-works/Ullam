import Foundation
import SwiftData

enum MediaType: String, Codable {
    case image
    case video
    case audio
}

@Model
final class MediaAttachment {
    var id: UUID = UUID()
    var page: Page?

    var mediaType: MediaType = MediaType.image
    var fileName: String = ""
    var thumbnailFileName: String?

    var isEncrypted: Bool = false
    var orderIndex: Int = 0
    var createdAt: Date = Date()

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
