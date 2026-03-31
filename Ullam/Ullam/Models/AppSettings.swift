import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()

    var defaultDiaryId: UUID?
    var hasCompletedOnboarding: Bool = false
    var lastOpenedDate: Date?

    // Writing goal
    var dailyWordGoal: Int = 200
    var isWritingGoalEnabled: Bool = false

    // Ambiance
    var ambienceSound: String? // nil = off, "rain", "fireplace", "lofi", "forest"
    var ambienceVolume: Double = 0.5
    var ambienceAutoPlay: Bool = false

    // Throwback
    var throwbackEnabled: Bool = true

    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
    }
}
