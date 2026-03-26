import SwiftUI
import SwiftData

#if os(iOS)
struct TodayFeedMobileView: View {
    @Bindable var diaryManager: DiaryManager

    @State private var pages: [Page] = []
    @State private var decryptedPages: [(page: Page, title: String, body: String, emojis: [String])] = []
    @State private var isLoading = true
    @State private var selectedPage: Page?
    @State private var showEditor = false
    @State private var dayMood: String?
    @State private var showMoodPicker = false
    @State private var pageToDelete: Page?
    @State private var showDeleteConfirmation = false

    private let selectedDate = Date()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    /// Group pages by day
    private var groupedByDay: [(date: Date, entries: [(page: Page, title: String, body: String, emojis: [String])])] {
        var groups: [(date: Date, entries: [(page: Page, title: String, body: String, emojis: [String])])] = []
        let cal = Calendar.current
        for entry in decryptedPages {
            let dayStart = cal.startOfDay(for: entry.page.createdAt)
            if let last = groups.last, cal.isDate(last.date, inSameDayAs: dayStart) {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((date: dayStart, entries: [entry]))
            }
        }
        return groups
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Date header
                Text(formattedDate)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Mood button
                if let mood = dayMood {
                    Button { showMoodPicker = true } label: {
                        HStack(spacing: 6) {
                            Text(mood).font(.system(size: 18))
                            Text("Today's mood")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.dimText)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    Button { showMoodPicker = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(AppTheme.accent)
                            Text("Set today's mood")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if decryptedPages.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(groupedByDay.enumerated()), id: \.element.date) { groupIdx, group in
                        // Date section header
                        dateLabel(for: group.date)
                            .padding(.horizontal, 20)
                            .padding(.top, groupIdx == 0 ? 0 : 20)
                            .padding(.bottom, 8)

                        // Entry cards
                        ForEach(group.entries, id: \.page.id) { entry in
                            Button {
                                selectedPage = entry.page
                                showEditor = true
                            } label: {
                                entryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    pageToDelete = entry.page
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Page", systemImage: "trash")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }
                    }
                }
            }
            .padding(.bottom, 80)
        }
        .background(AppTheme.bg)
        .overlay(alignment: .bottomTrailing) {
            Button { createNewPage() } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 52, height: 52)
                        .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
        .task { await loadData() }
        .onChange(of: diaryManager.currentDiary?.id) { _, _ in
            Task { await loadData() }
        }
        .sheet(isPresented: $showEditor) {
            if let page = selectedPage {
                NavigationStack {
                    PageEditorMobileView(diaryManager: diaryManager, page: page, date: selectedDate)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showEditor = false
                                    Task { await loadData() }
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showMoodPicker) {
            EmojiPickerView(selectedEmoji: $dayMood) { emoji in
                dayMood = emoji
                Task { await diaryManager.setDayMood(emoji, for: selectedDate) }
                showMoodPicker = false
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Page", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                pageToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let page = pageToDelete {
                    deletePage(page)
                }
            }
        } message: {
            Text("Are you sure you want to delete this page? This action cannot be undone.")
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        pages = diaryManager.getRecentPages(days: 14)

        let todayPages = diaryManager.getPages(for: selectedDate)
        if todayPages.isEmpty, let newPage = diaryManager.createPage(for: selectedDate) {
            pages.insert(newPage, at: 0)
        }

        var results: [(page: Page, title: String, body: String, emojis: [String])] = []
        for page in pages {
            if let decrypted = await diaryManager.decryptPage(page) {
                let plainText: String
                if let data = decrypted.content,
                   let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                    plainText = attr.string
                } else { plainText = "" }
                results.append((page: page, title: decrypted.title, body: plainText, emojis: decrypted.emojis))
            }
        }
        decryptedPages = results

        if let mood = diaryManager.getDayMood(for: selectedDate) {
            dayMood = await diaryManager.decryptDayMood(mood)
        }
        isLoading = false
    }

    private func createNewPage() {
        if let newPage = diaryManager.createPage(for: selectedDate) {
            selectedPage = newPage
            showEditor = true
        }
    }

    private func deletePage(_ page: Page) {
        pages.removeAll { $0.id == page.id }
        decryptedPages.removeAll { $0.page.id == page.id }
        diaryManager.deletePage(page)
        pageToDelete = nil
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.dimText)
            Text("No entries yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
            Text("Tap + to create your first entry")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func dateLabel(for date: Date) -> some View {
        let cal = Calendar.current
        let label: String
        if cal.isDateInToday(date) { label = "Today" }
        else if cal.isDateInYesterday(date) { label = "Yesterday" }
        else {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMMM d"
            label = f.string(from: date)
        }
        return Text(label)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white.opacity(0.6))
    }

    private func entryCard(entry: (page: Page, title: String, body: String, emojis: [String])) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Time + emojis row
            HStack(spacing: 6) {
                Text(formatTime(entry.page.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
                ForEach(entry.emojis, id: \.self) { e in
                    Text(e).font(.system(size: 12))
                }
                Spacer()
            }
            .padding(.bottom, 4)

            // Card
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title.isEmpty ? "Untitled Entry" : entry.title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(.black.opacity(0.85))
                    .lineLimit(2)

                if !entry.body.isEmpty {
                    Text(String(entry.body.prefix(150)))
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.5))
                        .lineSpacing(4)
                        .lineLimit(4)
                } else {
                    Text("Tap to start writing...")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.25))
                        .italic()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.cardBg)
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TodayFeedMobileView(diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext))
    }
}
#endif // os(iOS)
