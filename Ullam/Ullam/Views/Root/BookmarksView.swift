#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct BookmarksView: View {
    @Bindable var diaryManager: DiaryManager

    @State private var bookmarkedPages: [(page: Page, title: String, body: String, emojis: [String])] = []
    @State private var isLoading = true
    @State private var selectedPage: Page?
    @State private var appeared = false

    var body: some View {
        ZStack {
            bookmarksBackground.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(AppTheme.dimText)
                    Text("Loading bookmarks\u{2026}")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }
            } else if bookmarkedPages.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(bookmarkedPages.enumerated()), id: \.element.page.id) { index, entry in
                            Button {
                                selectedPage = entry.page
                            } label: {
                                bookmarkCard(entry: entry)
                            }
                            .buttonStyle(BookmarkCardButtonStyle())
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 15)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                .delay(Double(index) * 0.06),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBookmarks() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(item: $selectedPage, onDismiss: {
            Task { await loadBookmarks() }
        }) { page in
            PageEditorMobileView(diaryManager: diaryManager, page: page, date: page.date)
                .presentationBackground(AppTheme.bg)
        }
    }

    // MARK: - Background

    private var bookmarksBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.bg, AppTheme.bg, AppTheme.sidebarBg],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [AppTheme.accent.opacity(0.05), .clear], center: .topLeading, startRadius: 20, endRadius: 350)
            RadialGradient(colors: [AppTheme.gradientPink.opacity(0.03), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 300)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.06))
                    .frame(width: 90, height: 90)
                Image(systemName: "bookmark")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.accent.opacity(0.35))
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.6)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: appeared)

            VStack(spacing: 6) {
                Text("No bookmarked pages yet")
                    .font(.custom("NewYork-Bold", size: 18, relativeTo: .title3))
                    .foregroundStyle(AppTheme.sage)
                Text("Bookmark your favorite entries to find them here")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.dimText)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Bookmark Card

    private func bookmarkCard(entry: (page: Page, title: String, body: String, emojis: [String])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title.isEmpty ? "Untitled Entry" : entry.title)
                        .font(.custom("NewYork-Bold", size: 17, relativeTo: .headline))
                        .foregroundStyle(entry.title.isEmpty ? AppTheme.dimText : AppTheme.primaryText)
                        .lineLimit(2)

                    Text(formatDate(entry.page.createdAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.dimText)
                }

                Spacer()

                HStack(spacing: 6) {
                    if !entry.emojis.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(entry.emojis, id: \.self) { e in
                                Text(e).font(.system(size: 14))
                            }
                        }
                    }

                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accent.opacity(0.5))
                }
            }

            if !entry.body.isEmpty {
                Text(String(entry.body.prefix(140)))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(4)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )
        )
    }

    // MARK: - Data

    private func loadBookmarks() async {
        isLoading = true
        let allPages = diaryManager.getAllPages()
        let bookmarked = allPages.filter { $0.isBookmarked }.sorted { $0.createdAt > $1.createdAt }

        var results: [(page: Page, title: String, body: String, emojis: [String])] = []
        for page in bookmarked {
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
                results.append((page: page, title: decrypted.title, body: plainText, emojis: decrypted.emojis))
            }
        }
        bookmarkedPages = results
        isLoading = false
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return f.string(from: date)
    }
}

private struct BookmarkCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
#endif
