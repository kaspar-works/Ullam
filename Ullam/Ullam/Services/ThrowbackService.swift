import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class ThrowbackService {

    static let shared = ThrowbackService()
    private init() {}

    // MARK: - Quick check (no decryption)

    func hasThrowback(diaryManager: DiaryManager, for date: Date) -> Bool {
        guard let diary = diaryManager.currentDiary else { return false }
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let currentYear = calendar.component(.year, from: date)

        // Check previous years for entries on this month/day
        let allPages = diaryManager.getAllPages()
        for page in allPages {
            let pageYear = calendar.component(.year, from: page.date)
            let pageMonth = calendar.component(.month, from: page.date)
            let pageDay = calendar.component(.day, from: page.date)
            if pageMonth == month && pageDay == day && pageYear < currentYear {
                return true
            }
        }
        return false
    }

    // MARK: - Full throwback with decryption

    func getThrowback(diaryManager: DiaryManager, for date: Date) async -> [(page: Page, title: String, body: String, yearsAgo: Int)]? {
        guard let diary = diaryManager.currentDiary else { return nil }
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let currentYear = calendar.component(.year, from: date)

        let allPages = diaryManager.getAllPages()
        var results: [(page: Page, title: String, body: String, yearsAgo: Int)] = []

        for page in allPages {
            let pageYear = calendar.component(.year, from: page.date)
            let pageMonth = calendar.component(.month, from: page.date)
            let pageDay = calendar.component(.day, from: page.date)

            if pageMonth == month && pageDay == day && pageYear < currentYear {
                if let decrypted = await diaryManager.decryptPage(page) {
                    let plainText: String
                    if let data = decrypted.content,
                       let attr = try? NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                       ) {
                        plainText = attr.string
                    } else {
                        plainText = ""
                    }

                    let yearsAgo = currentYear - pageYear
                    results.append((page: page, title: decrypted.title, body: plainText, yearsAgo: yearsAgo))
                }
            }
        }

        return results.isEmpty ? nil : results.sorted { $0.yearsAgo < $1.yearsAgo }
    }
}
