import Foundation
import SwiftData

@MainActor
final class TagService {

    static let shared = TagService()
    private init() {}

    /// Create a new tag for the given diary.
    @discardableResult
    func createTag(name: String, color: String, diary: Diary, context: ModelContext) -> Tag {
        let tag = Tag(name: name, color: color, diary: diary)
        context.insert(tag)
        try? context.save()
        return tag
    }

    /// Fetch all tags belonging to the given diary.
    func getAllTags(for diary: Diary, context: ModelContext) -> [Tag] {
        let diaryId = diary.id
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { tag in
                tag.diary?.id == diaryId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Adds a tag to a page (many-to-many via ID arrays).
    func addTag(_ tag: Tag, to page: Page) {
        if !page.tagIds.contains(tag.id) {
            page.tagIds.append(tag.id)
        }
        if !tag.pageIds.contains(page.id) {
            tag.pageIds.append(page.id)
        }
    }

    /// Removes a tag from a page.
    func removeTag(_ tag: Tag, from page: Page) {
        page.tagIds.removeAll { $0 == tag.id }
        tag.pageIds.removeAll { $0 == page.id }
    }

    /// Get all pages that have a given tag in the diary.
    func getPages(for tag: Tag, diary: Diary, context: ModelContext) -> [Page] {
        let diaryId = diary.id
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.diary?.id == diaryId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let allPages = try? context.fetch(descriptor) else { return [] }
        return allPages.filter { $0.tagIds.contains(tag.id) }
    }

    /// Seeds a default set of tags for a new diary.
    func seedDefaultTags(diary: Diary, context: ModelContext) {
        let defaults: [(String, String)] = [
            ("Travel", "blue"),
            ("Work", "orange"),
            ("Personal", "purple"),
            ("Dream", "pink"),
            ("Health", "green"),
            ("Creative", "yellow")
        ]
        for (name, color) in defaults {
            createTag(name: name, color: color, diary: diary, context: context)
        }
    }
}
