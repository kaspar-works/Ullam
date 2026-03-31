import Foundation
import SwiftData
import CryptoKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class DiaryManager {
    private let modelContext: ModelContext
    private let encryptionManager = EncryptionManager.shared

    private(set) var currentDiary: Diary?
    private var currentKey: SymmetricKey?

    var isUnlocked: Bool {
        currentDiary != nil
    }

    // MARK: - Default Diary

    func getDefaultDiary() -> Diary? {
        let descriptor = FetchDescriptor<Diary>(
            predicate: #Predicate { !$0.isProtected }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func isDefaultDiaryProtected() -> Bool {
        // If there's no unprotected diary, default is considered protected
        return getDefaultDiary() == nil
    }

    func openDefaultDiaryIfUnprotected() -> Bool {
        if let diary = getDefaultDiary() {
            currentDiary = diary
            currentKey = nil
            return true
        }
        return false
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Diary Access

    func unlockDiary(with pincode: String) async -> Bool {
        let descriptor = FetchDescriptor<Diary>()
        guard let diaries = try? modelContext.fetch(descriptor) else {
            return false
        }

        for diary in diaries {
            if diary.isProtected {
                guard let salt = diary.encryptionSalt,
                      let storedHash = diary.pincodeHash else { continue }

                let isValid = await encryptionManager.verifyPincode(pincode, againstHash: storedHash, salt: salt)

                if isValid {
                    currentDiary = diary
                    currentKey = await encryptionManager.deriveKey(from: pincode, salt: salt)

                    // Decrypt diary name if needed
                    if let encryptedName = diary.encryptedName,
                       let key = currentKey {
                        diary.plaintextName = try? await encryptionManager.decryptString(encryptedName, using: key)
                    }

                    return true
                }
            }
        }

        return false
    }

    func openDefaultDiary() -> Bool {
        let descriptor = FetchDescriptor<Diary>(
            predicate: #Predicate { !$0.isProtected }
        )

        if let diary = try? modelContext.fetch(descriptor).first {
            currentDiary = diary
            currentKey = nil
            return true
        }

        return false
    }

    func openDiary(_ diary: Diary) {
        guard !diary.isProtected else { return }
        currentDiary = diary
        currentKey = nil
    }

    func unlockSpecificDiary(_ diary: Diary, with pincode: String) async -> Bool {
        guard diary.isProtected,
              let salt = diary.encryptionSalt,
              let storedHash = diary.pincodeHash else {
            return false
        }

        let isValid = await encryptionManager.verifyPincode(pincode, againstHash: storedHash, salt: salt)

        if isValid {
            currentDiary = diary
            currentKey = await encryptionManager.deriveKey(from: pincode, salt: salt)

            // Decrypt diary name if needed
            if let encryptedName = diary.encryptedName,
               let key = currentKey {
                diary.plaintextName = try? await encryptionManager.decryptString(encryptedName, using: key)
            }

            return true
        }

        return false
    }

    func lockCurrentDiary() {
        currentDiary = nil
        currentKey = nil
    }

    // MARK: - Pincode Management

    /// Set up a new pincode on the current diary (first time or change)
    func setupPincode(_ pincode: String) async -> Bool {
        guard let diary = currentDiary else { return false }

        let salt = await encryptionManager.generateSalt()
        let hash = await encryptionManager.hashPincode(pincode, salt: salt)
        let key = await encryptionManager.deriveKey(from: pincode, salt: salt)

        diary.encryptionSalt = salt
        diary.pincodeHash = hash
        diary.isProtected = true

        // Encrypt the diary name
        diary.encryptedName = try? await encryptionManager.encryptString(diary.name, using: key)

        // Re-encrypt all existing pages
        for page in diary.pages ?? [] {
            // First decrypt with old key (if any) or read plaintext
            let title = page.plaintextTitle ?? ""
            let subtitle = page.plaintextSubtitle
            let content = page.plaintextContent
            let emojis = page.plaintextEmojis ?? []

            // Encrypt with new key
            page.encryptedTitle = try? await encryptionManager.encryptString(title, using: key)
            page.plaintextTitle = nil

            if let sub = subtitle {
                page.encryptedSubtitle = try? await encryptionManager.encryptString(sub, using: key)
            }
            page.plaintextSubtitle = nil

            if let data = content {
                page.encryptedContent = try? await encryptionManager.encrypt(data, using: key)
            }
            page.plaintextContent = nil

            if let emojisData = try? JSONEncoder().encode(emojis) {
                page.encryptedEmojis = try? await encryptionManager.encrypt(emojisData, using: key)
            }
            page.plaintextEmojis = nil
        }

        // Re-encrypt day moods
        for mood in (diary.dayMoods ?? []) {
            if let emoji = mood.plaintextEmoji {
                mood.encryptedEmoji = try? await encryptionManager.encryptString(emoji, using: key)
                mood.plaintextEmoji = nil
            }
        }

        currentKey = key
        try? modelContext.save()
        return true
    }

    /// Remove pincode from current diary (decrypt everything)
    func removePincode() async -> Bool {
        guard let diary = currentDiary, diary.isProtected, let key = currentKey else { return false }

        // Decrypt all pages back to plaintext
        for page in diary.pages ?? [] {
            if let encTitle = page.encryptedTitle {
                page.plaintextTitle = try? await encryptionManager.decryptString(encTitle, using: key)
            }
            page.encryptedTitle = nil

            if let encSub = page.encryptedSubtitle {
                page.plaintextSubtitle = try? await encryptionManager.decryptString(encSub, using: key)
            }
            page.encryptedSubtitle = nil

            if let encContent = page.encryptedContent {
                page.plaintextContent = try? await encryptionManager.decrypt(encContent, using: key)
            }
            page.encryptedContent = nil

            if let encEmojis = page.encryptedEmojis,
               let decryptedData = try? await encryptionManager.decrypt(encEmojis, using: key),
               let decoded = try? JSONDecoder().decode([String].self, from: decryptedData) {
                page.plaintextEmojis = decoded
            }
            page.encryptedEmojis = nil
        }

        // Decrypt day moods
        for mood in (diary.dayMoods ?? []) {
            if let encEmoji = mood.encryptedEmoji {
                mood.plaintextEmoji = try? await encryptionManager.decryptString(encEmoji, using: key)
                mood.encryptedEmoji = nil
            }
        }

        // Restore diary name
        if let encName = diary.encryptedName {
            diary.plaintextName = try? await encryptionManager.decryptString(encName, using: key)
        }
        diary.encryptedName = nil

        // Remove protection
        diary.isProtected = false
        diary.pincodeHash = nil
        diary.encryptionSalt = nil
        currentKey = nil

        try? modelContext.save()
        return true
    }

    /// Change pincode (verify old, set new)
    func changePincode(oldPincode: String, newPincode: String) async -> Bool {
        guard let diary = currentDiary, diary.isProtected,
              let salt = diary.encryptionSalt,
              let storedHash = diary.pincodeHash else { return false }

        // Verify old pincode
        let isValid = await encryptionManager.verifyPincode(oldPincode, againstHash: storedHash, salt: salt)
        guard isValid else { return false }

        // Decrypt everything with old key, then re-encrypt with new
        let oldKey = await encryptionManager.deriveKey(from: oldPincode, salt: salt)
        currentKey = oldKey

        // Remove pincode (decrypts everything)
        let removed = await removePincode()
        guard removed else { return false }

        // Set new pincode (re-encrypts everything)
        return await setupPincode(newPincode)
    }

    // MARK: - Visible Diaries

    func getVisibleDiaries() -> [Diary] {
        let descriptor = FetchDescriptor<Diary>(
            predicate: #Predicate { $0.isVisibleOnSwitch }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Diary Creation

    func createDiary(name: String, pincode: String?, isVisibleOnSwitch: Bool, storagePreference: StoragePreference = .local) async -> Diary {
        let diary = Diary(name: name, isProtected: pincode != nil, isVisibleOnSwitch: isVisibleOnSwitch, storagePreference: storagePreference)

        if let pincode = pincode {
            let salt = await encryptionManager.generateSalt()
            diary.encryptionSalt = salt
            diary.pincodeHash = await encryptionManager.hashPincode(pincode, salt: salt)

            let key = await encryptionManager.deriveKey(from: pincode, salt: salt)
            diary.encryptedName = try? await encryptionManager.encryptString(name, using: key)
            diary.plaintextName = nil
        }

        modelContext.insert(diary)
        try? modelContext.save()

        return diary
    }

    // MARK: - Page Management

    func createPage(for date: Date = Date()) -> Page? {
        guard let diary = currentDiary else { return nil }

        let page = Page(diary: diary, date: date)
        modelContext.insert(page)
        try? modelContext.save()

        return page
    }

    func getOrCreatePage(for date: Date) -> Page? {
        let pages = getPages(for: date)
        if let existingPage = pages.first {
            return existingPage
        }
        return createPage(for: date)
    }

    func savePage(_ page: Page, title: String, subtitle: String?, content: Data?, emojis: [String]) async {
        guard let diary = page.diary else { return }

        if diary.isProtected, let key = currentKey {
            page.encryptedTitle = try? await encryptionManager.encryptString(title, using: key)
            page.plaintextTitle = nil

            if let subtitle = subtitle {
                page.encryptedSubtitle = try? await encryptionManager.encryptString(subtitle, using: key)
            }
            page.plaintextSubtitle = nil

            if let data = content {
                page.encryptedContent = try? await encryptionManager.encrypt(data, using: key)
            }
            page.plaintextContent = nil

            if let emojisData = try? JSONEncoder().encode(emojis) {
                page.encryptedEmojis = try? await encryptionManager.encrypt(emojisData, using: key)
            }
            page.plaintextEmojis = nil
        } else {
            page.plaintextTitle = title
            page.plaintextSubtitle = subtitle
            page.plaintextContent = content
            page.plaintextEmojis = emojis
        }

        page.modifiedAt = Date()
        try? modelContext.save()

        // Update widgets with latest data
        await WidgetBridge.updateWidgetData(diaryManager: self)
    }

    func decryptPage(_ page: Page) async -> (title: String, subtitle: String?, content: Data?, emojis: [String])? {
        guard let diary = page.diary else { return nil }

        if diary.isProtected, let key = currentKey {
            let title = (try? await encryptionManager.decryptString(page.encryptedTitle ?? Data(), using: key)) ?? ""

            var subtitle: String?
            if let encryptedSubtitle = page.encryptedSubtitle {
                subtitle = try? await encryptionManager.decryptString(encryptedSubtitle, using: key)
            }

            var content: Data?
            if let encryptedContent = page.encryptedContent {
                content = try? await encryptionManager.decrypt(encryptedContent, using: key)
            }

            var emojis: [String] = []
            if let encryptedEmojis = page.encryptedEmojis,
               let decryptedData = try? await encryptionManager.decrypt(encryptedEmojis, using: key),
               let decoded = try? JSONDecoder().decode([String].self, from: decryptedData) {
                emojis = decoded
            }

            return (title, subtitle, content, emojis)
        } else {
            return (page.plaintextTitle ?? "", page.plaintextSubtitle, page.plaintextContent, page.plaintextEmojis ?? [])
        }
    }

    func deletePage(_ page: Page) {
        modelContext.delete(page)
        try? modelContext.save()
    }

    // MARK: - Day Mood

    func getDayMood(for date: Date) -> DayMood? {
        guard let diary = currentDiary else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let diaryId = diary.id

        let descriptor = FetchDescriptor<DayMood>(
            predicate: #Predicate { mood in
                mood.diary?.id == diaryId && mood.date == startOfDay
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    func setDayMood(_ emoji: String, for date: Date) async {
        guard let diary = currentDiary else { return }

        let startOfDay = Calendar.current.startOfDay(for: date)

        if let existingMood = getDayMood(for: date) {
            if diary.isProtected, let key = currentKey {
                existingMood.encryptedEmoji = try? await encryptionManager.encryptString(emoji, using: key)
                existingMood.plaintextEmoji = nil
            } else {
                existingMood.plaintextEmoji = emoji
            }
            existingMood.modifiedAt = Date()
        } else {
            let newMood = DayMood(diary: diary, date: startOfDay)
            if diary.isProtected, let key = currentKey {
                newMood.encryptedEmoji = try? await encryptionManager.encryptString(emoji, using: key)
                newMood.plaintextEmoji = nil
            } else {
                newMood.plaintextEmoji = emoji
            }
            modelContext.insert(newMood)
        }

        try? modelContext.save()

        // Update widgets with latest mood
        await WidgetBridge.updateWidgetData(diaryManager: self)
    }

    func decryptDayMood(_ mood: DayMood) async -> String? {
        guard let diary = mood.diary else { return nil }

        if diary.isProtected, let key = currentKey {
            if let encryptedEmoji = mood.encryptedEmoji {
                return try? await encryptionManager.decryptString(encryptedEmoji, using: key)
            }
            return nil
        } else {
            return mood.plaintextEmoji
        }
    }

    // MARK: - Search

    func searchEntries(query: String) async -> [Page] {
        guard let diary = currentDiary else { return [] }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lowercasedQuery = trimmed.lowercased()
        let diaryId = diary.id

        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.diary?.id == diaryId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let allPages = try? modelContext.fetch(descriptor) else { return [] }

        var results: [Page] = []

        for page in allPages {
            if diary.isProtected, let key = currentKey {
                // Decrypt and search
                if let decrypted = await decryptPage(page) {
                    let titleMatch = decrypted.title.lowercased().contains(lowercasedQuery)
                    let subtitleMatch = decrypted.subtitle?.lowercased().contains(lowercasedQuery) ?? false
                    let contentMatch: Bool
                    if let contentData = decrypted.content,
                       let contentString = String(data: contentData, encoding: .utf8) {
                        contentMatch = contentString.lowercased().contains(lowercasedQuery)
                    } else {
                        contentMatch = false
                    }

                    if titleMatch || subtitleMatch || contentMatch {
                        results.append(page)
                    }
                }
            } else {
                // Search plaintext fields directly
                let titleMatch = (page.plaintextTitle ?? "").lowercased().contains(lowercasedQuery)
                let subtitleMatch = (page.plaintextSubtitle ?? "").lowercased().contains(lowercasedQuery)
                let contentMatch: Bool
                if let contentData = page.plaintextContent,
                   let contentString = String(data: contentData, encoding: .utf8) {
                    contentMatch = contentString.lowercased().contains(lowercasedQuery)
                } else {
                    contentMatch = false
                }

                if titleMatch || subtitleMatch || contentMatch {
                    results.append(page)
                }
            }
        }

        return results
    }

    // MARK: - Export

    /// Fetch all pages for the current diary, sorted by date ascending.
    func getAllPages() -> [Page] {
        guard let diary = currentDiary else { return [] }

        let diaryId = diary.id
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.diary?.id == diaryId
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Decrypt all pages and return tuples suitable for PDFExporter.
    func decryptAllPagesForExport() async -> [(title: String, body: String, date: Date, emojis: [String])] {
        let pages = getAllPages()
        var results: [(title: String, body: String, date: Date, emojis: [String])] = []

        for page in pages {
            if let decrypted = await decryptPage(page) {
                let bodyString: String
                if let contentData = decrypted.content {
                    // Content is stored as RTF; extract plain text
                    if let attrStr = try? NSAttributedString(
                        data: contentData,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    ) {
                        bodyString = attrStr.string
                    } else {
                        // Fallback: try raw UTF-8
                        bodyString = String(data: contentData, encoding: .utf8) ?? ""
                    }
                } else {
                    bodyString = ""
                }

                results.append((
                    title: decrypted.title,
                    body: bodyString,
                    date: page.date,
                    emojis: decrypted.emojis
                ))
            }
        }

        return results
    }

    // MARK: - Queries

    func getPages(for date: Date) -> [Page] {
        guard let diary = currentDiary else { return [] }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let diaryId = diary.id

        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.diary?.id == diaryId &&
                page.date >= startOfDay &&
                page.date < endOfDay
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getRecentPages(days: Int = 14) -> [Page] {
        guard let diary = currentDiary else { return [] }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        let diaryId = diary.id

        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.diary?.id == diaryId &&
                page.date >= startDate
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getPages(from startDate: Date, to endDate: Date) -> [Page] {
        guard let diary = currentDiary else { return [] }
        let diaryId = diary.id

        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate { page in
                page.diary?.id == diaryId &&
                page.date >= startDate &&
                page.date < endDate
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func decryptPageEmojis(_ page: Page) async -> [String] {
        // Try plaintext emojis first (unprotected diaries)
        if let plain = page.plaintextEmojis, !plain.isEmpty {
            return plain.filter { !$0.isEmpty }
        }
        // Try encrypted emojis (protected diaries)
        guard let data = page.encryptedEmojis, let key = currentKey else { return [] }
        if let decrypted = try? await encryptionManager.decrypt(data, using: key),
           let str = String(data: decrypted, encoding: .utf8) {
            return str.components(separatedBy: ",").filter { !$0.isEmpty }
        }
        return []
    }

    func getYearMoods(for year: Int) -> [DayMood] {
        guard let diary = currentDiary else { return [] }

        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }

        let diaryId = diary.id

        let descriptor = FetchDescriptor<DayMood>(
            predicate: #Predicate { mood in
                mood.diary?.id == diaryId &&
                mood.date >= startOfYear &&
                mood.date < endOfYear
            }
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
