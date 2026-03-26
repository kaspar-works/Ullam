import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID

    var defaultDiaryId: UUID?
    var hasCompletedOnboarding: Bool
    var lastOpenedDate: Date?

    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
    }
}
