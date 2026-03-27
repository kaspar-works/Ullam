import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()

    var defaultDiaryId: UUID?
    var hasCompletedOnboarding: Bool = false
    var lastOpenedDate: Date?

    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
    }
}
