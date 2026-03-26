import SwiftUI
import SwiftData

struct SearchView: View {
    @Bindable var diaryManager: DiaryManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var results: [Page] = []
    @State private var isSearching: Bool = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header with search field
            VStack(spacing: 12) {
                HStack {
                    Text("Search")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.dimText)

                    TextField("Search pages...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.dimText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.subtle)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().opacity(0.1)

            // Results
            if isSearching {
                Spacer()
                ProgressView()
                    .tint(AppTheme.accent)
                Spacer()
            } else if results.isEmpty && !searchQuery.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.dimText)
                    Text("No results found")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                    Text("Try a different search term")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.dimText)
                }
                Spacer()
            } else if results.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.dimText)
                    Text("Search your pages")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                    Text("Find pages by title or content")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.dimText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results, id: \.id) { page in
                            SearchResultRow(page: page, diaryManager: diaryManager, dateFormatter: dateFormatter)
                                .onTapGesture {
                                    dismiss()
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .background(AppTheme.bg)
        .preferredColorScheme(.dark)
        .onChange(of: searchQuery) { _, newValue in
            if newValue.isEmpty {
                results = []
            } else {
                performSearch()
            }
        }
    }

    private func performSearch() {
        let query = searchQuery
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            return
        }
        isSearching = true
        Task {
            let found = await diaryManager.searchEntries(query: query)
            if searchQuery == query {
                results = found
                isSearching = false
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let page: Page
    let diaryManager: DiaryManager
    let dateFormatter: DateFormatter

    @State private var displayTitle: String = ""
    @State private var previewText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayTitle.isEmpty ? "Untitled" : displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(dateFormatter.string(from: page.date))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.dimText)
            }

            if !previewText.isEmpty {
                Text(previewText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.mutedText)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.cardBg.opacity(0.06))
        )
        .contentShape(Rectangle())
        .task {
            await loadContent()
        }
    }

    private func loadContent() async {
        if let decrypted = await diaryManager.decryptPage(page) {
            displayTitle = decrypted.title
            if let contentData = decrypted.content,
               let contentString = String(data: contentData, encoding: .utf8) {
                // Strip RTF tags for preview - take plain text approximation
                let cleaned = contentString
                    .replacingOccurrences(of: "\\{[^}]*\\}", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\\\[a-zA-Z0-9]+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                previewText = String(cleaned.prefix(150))
            }
        } else {
            displayTitle = page.plaintextTitle ?? ""
            if let contentData = page.plaintextContent,
               let contentString = String(data: contentData, encoding: .utf8) {
                let cleaned = contentString
                    .replacingOccurrences(of: "\\{[^}]*\\}", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\\\[a-zA-Z0-9]+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                previewText = String(cleaned.prefix(150))
            }
        }
    }
}
