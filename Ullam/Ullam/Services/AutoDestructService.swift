import Foundation
import SwiftData

/// Manages auto-destruct timers on diary pages.
/// Pages with an expired `autoDestructDate` are permanently deleted on cleanup.
@MainActor
final class AutoDestructService {

    static let shared = AutoDestructService()
    private init() {}

    /// Set auto-destruct date on a page (now + given number of days).
    func setAutoDestruct(page: Page, after days: Int) {
        page.autoDestructDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
        page.modifiedAt = Date()
    }

    /// Remove auto-destruct from a page.
    func removeAutoDestruct(page: Page) {
        page.autoDestructDate = nil
        page.modifiedAt = Date()
    }

    /// Delete all pages whose autoDestructDate has passed.
    func cleanupExpiredPages(context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.autoDestructDate != nil
            }
        )

        guard let pages = try? context.fetch(descriptor) else { return }

        for page in pages {
            if let destroyDate = page.autoDestructDate, destroyDate < now {
                context.delete(page)
            }
        }

        try? context.save()
    }

    /// Return pages expiring within the next 24 hours.
    func getExpiringPages(context: ModelContext) -> [Page] {
        let now = Date()
        guard let tomorrow = Calendar.current.date(byAdding: .hour, value: 24, to: now) else { return [] }

        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.autoDestructDate != nil
            }
        )

        guard let pages = try? context.fetch(descriptor) else { return [] }

        return pages.filter { page in
            guard let destroyDate = page.autoDestructDate else { return false }
            return destroyDate > now && destroyDate <= tomorrow
        }
    }
}
