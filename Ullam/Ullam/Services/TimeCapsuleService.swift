import Foundation
import SwiftData

@MainActor
final class TimeCapsuleService {

    static let shared = TimeCapsuleService()
    private init() {}

    // MARK: - Create

    func createCapsule(diary: Diary, message: String, unlockDate: Date, context: ModelContext) -> TimeCapsule {
        let capsule = TimeCapsule(diary: diary, message: message, unlockDate: unlockDate)
        context.insert(capsule)
        try? context.save()
        return capsule
    }

    // MARK: - Queries

    func getUnlockedCapsules(diary: Diary, context: ModelContext) -> [TimeCapsule] {
        let now = Date()
        let diaryId = diary.id
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate { capsule in
                capsule.diary?.id == diaryId &&
                capsule.unlockDate <= now &&
                capsule.isOpened == false
            },
            sortBy: [SortDescriptor(\.unlockDate, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func getAllCapsules(diary: Diary, context: ModelContext) -> [TimeCapsule] {
        let diaryId = diary.id
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate { capsule in
                capsule.diary?.id == diaryId
            },
            sortBy: [SortDescriptor(\.unlockDate, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func openCapsule(_ capsule: TimeCapsule) {
        capsule.isOpened = true
        capsule.openedDate = Date()
    }

    func getPendingCount(diary: Diary, context: ModelContext) -> Int {
        let now = Date()
        let diaryId = diary.id
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate { capsule in
                capsule.diary?.id == diaryId &&
                capsule.unlockDate > now
            }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
