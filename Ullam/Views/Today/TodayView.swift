import SwiftUI
import SwiftData

// MARK: - Today Feed View (macOS)

struct TodayFeedView: View {
    @Bindable var diaryManager: DiaryManager

    @State private var pages: [Page] = []
    @State private var decryptedPages: [(page: Page, title: String, body: String, emojis: [String])] = []
    @State private var dayMood: String?
    @State private var isLoading = true
    @State private var selectedPage: Page?
    @State private var showEditor = false
    @State private var wordCount: Int = 0
    @State private var showingMoodPicker = false
    @State private var editorImages: [ImageAttachment] = []
    @State private var pageImages: [UUID: [ImageAttachment]] = [:]
    @State private var pageToDelete: Page?
    @State private var showDeleteConfirmation = false
    @State private var allDiaryPages: [Page] = []

    private let selectedDate = Date()

    var body: some View {
        HStack(spacing: 0) {
            if showEditor, let page = selectedPage {
                // Inline editor
                VStack(spacing: 0) {
                    // Back button bar
                    HStack {
                        Button {
                            // Save images for this page before going back
                            if let p = selectedPage, !editorImages.isEmpty {
                                pageImages[p.id] = editorImages
                            }
                            showEditor = false
                            Task { await loadData() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back to Today")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    PageEditorView(diaryManager: diaryManager, page: page, date: selectedDate, attachedImages: $editorImages)
                        .id(page.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Timeline feed
                timelineFeed
                    .frame(maxWidth: .infinity)
            }

            // Right sidebar — context-aware
            if showEditor, let page = selectedPage {
                entrySidebar(for: page)
                    .frame(width: 220)
            } else {
                daySummarySidebar
                    .frame(width: 220)
            }
        }
        .task { await loadData() }
        .onChange(of: diaryManager.currentDiary?.id) { _, _ in
            Task { await loadData() }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        // Load recent pages (last 14 days) for the feed
        pages = diaryManager.getRecentPages(days: 14)

        // Decrypt all pages
        var results: [(page: Page, title: String, body: String, emojis: [String])] = []
        var totalWords = 0

        for page in pages {
            if let decrypted = await diaryManager.decryptPage(page) {
                let plainText: String
                if let contentData = decrypted.content,
                   let attributed = try? NSAttributedString(
                       data: contentData,
                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                       documentAttributes: nil
                   ) {
                    plainText = attributed.string
                } else {
                    plainText = ""
                }
                totalWords += plainText.split(separator: " ").count
                results.append((page: page, title: decrypted.title, body: plainText, emojis: decrypted.emojis))
            }
        }

        decryptedPages = results
        wordCount = totalWords

        // Load all pages for streak calculation
        allDiaryPages = diaryManager.getRecentPages(days: 365)

        // Load day mood
        if let mood = diaryManager.getDayMood(for: selectedDate) {
            dayMood = await diaryManager.decryptDayMood(mood)
        }

        isLoading = false
    }

    private func createNewPage() {
        if let newPage = diaryManager.createPage(for: selectedDate) {
            pages.insert(newPage, at: 0)
            selectedPage = newPage
            showEditor = true
        }
    }

    // MARK: - Timeline Feed

    /// Group decrypted pages by day
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

    private var timelineFeed: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - 48 // padding
            let cardMinWidth: CGFloat = 300
            let columns = max(1, Int(availableWidth / cardMinWidth))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if decryptedPages.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(groupedByDay.enumerated()), id: \.element.date) { groupIndex, group in
                            // Date header
                            dateHeader(for: group.date)
                                .padding(.horizontal, 24)
                                .padding(.top, groupIndex == 0 ? 8 : 24)
                                .padding(.bottom, 8)

                            // Cards in adaptive grid
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns),
                                spacing: 12
                            ) {
                                ForEach(group.entries, id: \.page.id) { entry in
                                    let timeStr = formatTime(entry.page.createdAt)
                                    let moodLabel = entry.emojis.first ?? ""

                                    Button {
                                        editorImages = pageImages[entry.page.id] ?? []
                                        selectedPage = entry.page
                                        showEditor = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Time + emoji
                                            entryTimestamp(time: timeStr, mood: moodLabel)

                                            // Card content
                                            entryCardContent(
                                                title: entry.title.isEmpty ? "Untitled Entry" : entry.title,
                                                body: entry.body.isEmpty ? "Tap to start writing..." : String(entry.body.prefix(200)),
                                                images: pageImages[entry.page.id] ?? []
                                            )
                                        }
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
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.bottom, 40)
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
    }

    private func deletePage(_ page: Page) {
        pages.removeAll { $0.id == page.id }
        decryptedPages.removeAll { $0.page.id == page.id }
        pageImages.removeValue(forKey: page.id)
        diaryManager.deletePage(page)
        pageToDelete = nil
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.dimText)
            Text("No entries today")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
            Button("Create First Entry") { createNewPage() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(Capsule())
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }

    private func dateHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let label: String
        if calendar.isDateInToday(date) {
            label = "Today"
        } else if calendar.isDateInYesterday(date) {
            label = "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            label = formatter.string(from: date)
        }

        return HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func entryTimestamp(time: String, mood: String) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.accent)

            if !mood.isEmpty {
                Text(mood)
                    .font(.system(size: 14))
            }
        }
    }

    private func entryCardContent(title: String, body: String, images: [ImageAttachment] = []) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(2)

            if !body.isEmpty && body != "Tap to start writing..." {
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.50))
                    .lineSpacing(4)
                    .lineLimit(5)
            } else {
                Text("Tap to start writing...")
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.25))
                    .italic()
            }

            // Attached images
            if !images.isEmpty {
                HStack(spacing: 6) {
                    ForEach(images.prefix(3)) { attachment in
                        #if canImport(UIKit)
                        Image(uiImage: attachment.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #else
                        Image(nsImage: attachment.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #endif
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBg)
        )
    }

    // MARK: - Day Summary Sidebar

    private var daySummarySidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("DAY SUMMARY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.mutedText)

                // Dominant Mood
                Button { showingMoodPicker = true } label: {
                    VStack(spacing: 6) {
                        if let mood = dayMood {
                            Text(mood).font(.system(size: 28))
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.accent)
                        }
                        Text(dayMood != nil ? "Tap to change" : "Set mood")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.subtle))
                }
                .buttonStyle(.plain)

                // Entry Emojis (compact, wrapping)
                if !entryEmojis.isEmpty {
                    Text("MOOD TAGS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.mutedText)

                    // Use a wrapping layout - limit to first 6
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 30, maximum: 36), spacing: 4)
                    ], spacing: 4) {
                        ForEach(Array(entryEmojis.prefix(6)), id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 16))
                                .frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.subtle))
                        }
                    }
                }

                // Entry Media
                Text("ENTRY MEDIA")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.mutedText)

                if !editorImages.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ], spacing: 4) {
                        ForEach(Array(editorImages.enumerated()), id: \.element.id) { index, attachment in
                            ZStack(alignment: .topTrailing) {
                                #if canImport(UIKit)
                                Image(uiImage: attachment.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                #else
                                Image(nsImage: attachment.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                #endif

                                Button { editorImages.remove(at: index) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 3, y: -3)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.subtle)
                                .frame(height: 50)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.dimText)
                                )
                        }
                    }
                }

                // Stats row
                HStack(spacing: 6) {
                    VStack(spacing: 3) {
                        Text("\(wordCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Words")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.dimText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.subtle))

                    VStack(spacing: 3) {
                        Text("\(decryptedPages.count)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Entries")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.dimText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.subtle))
                }

                // Writing Streak
                streakDisplay

                // Prompts
                Text("PROMPTS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.mutedText)

                promptCard(text: "What surprised you today?")
                promptCard(text: "Describe a scent from this morning.")

                // Moon Phase
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MOON PHASE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.dimText)
                        Text(moonPhaseName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: moonPhaseIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 20)
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
        .clipped()
        .background(AppTheme.sidebarBg)
        .overlay(alignment: .bottomTrailing) {
            Button { createNewPage() } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.8))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .sheet(isPresented: $showingMoodPicker) {
            EmojiPickerView(selectedEmoji: $dayMood) { emoji in
                dayMood = emoji
                Task { await diaryManager.setDayMood(emoji, for: selectedDate) }
                showingMoodPicker = false
            }
            #if os(iOS)
            .presentationDetents([.medium])
            #endif
        }
    }

    private var entryEmojis: [String] {
        decryptedPages.flatMap { $0.emojis }.uniqued()
    }

    private var streakDisplay: some View {
        let streak = StreakTracker.calculateStreak(pages: allDiaryPages)
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("\u{1F525}")
                    .font(.system(size: 18))
                Text("\(streak.currentStreak)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text(streak.currentStreak == 1 ? "day streak" : "day streak")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.dimText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.subtle))

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(streak.longestStreak)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Best")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.dimText)
                }
                VStack(spacing: 2) {
                    Text("\(streak.totalDaysWritten)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Total days")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.dimText)
                }
            }
        }
    }

    // MARK: - Entry-Specific Sidebar (when editing)

    private func entrySidebar(for page: Page) -> some View {
        let entry = decryptedPages.first(where: { $0.page.id == page.id })
        let entryTitle = entry?.title ?? "Untitled"
        let entryBody = entry?.body ?? ""
        let entryMoods = entry?.emojis ?? []
        let entryWordCount = entryBody.split(separator: " ").count
        let readingTime = max(1, entryWordCount / 200)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("ENTRY DETAILS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.mutedText)

                // Entry title
                Text(entryTitle.isEmpty ? "Untitled" : entryTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                // Entry time
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formatTime(page.createdAt))
                        .font(.system(size: 11))
                }
                .foregroundStyle(AppTheme.dimText)

                // Entry moods
                if !entryMoods.isEmpty {
                    Text("ENTRY MOOD")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.mutedText)

                    HStack(spacing: 6) {
                        ForEach(entryMoods, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 20))
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.subtle))
                        }
                    }
                }

                // Attached media
                Text("ATTACHED MEDIA")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.mutedText)

                if !editorImages.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ], spacing: 4) {
                        ForEach(Array(editorImages.enumerated()), id: \.element.id) { index, attachment in
                            ZStack(alignment: .topTrailing) {
                                #if canImport(UIKit)
                                Image(uiImage: attachment.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                #else
                                Image(nsImage: attachment.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                #endif

                                Button { editorImages.remove(at: index) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 3, y: -3)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.subtle)
                                .frame(height: 50)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.dimText)
                                )
                        }
                    }
                }

                // Writing stats for this entry
                Text("WRITING STATS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.mutedText)

                HStack(spacing: 6) {
                    VStack(spacing: 3) {
                        Text("\(entryWordCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Words")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.dimText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.subtle))

                    VStack(spacing: 3) {
                        Text("~\(readingTime) min")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Read time")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.dimText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.subtle))
                }

                // Diary info
                Text("DIARY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.mutedText)

                HStack(spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accent)
                    Text(diaryManager.currentDiary?.name ?? "Me & Me")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 20)
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
        .clipped()
        .background(AppTheme.sidebarBg)
    }

    private func statMini(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.subtle))
    }

    private func promptCard(text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(AppTheme.accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("PROMPT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.accent)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // Simple moon phase calc
    private var moonPhaseIcon: String {
        let day = Calendar.current.component(.day, from: Date())
        let phase = day % 30
        if phase < 4 { return "moon.fill" }
        if phase < 11 { return "moon.zzz" }
        if phase < 18 { return "sun.max.fill" }
        if phase < 25 { return "moon.zzz" }
        return "moon.fill"
    }

    private var moonPhaseName: String {
        let day = Calendar.current.component(.day, from: Date())
        let phase = day % 30
        if phase < 4 { return "New Moon" }
        if phase < 11 { return "Waxing Crescent" }
        if phase < 18 { return "Full Moon" }
        if phase < 25 { return "Waning Gibbous" }
        return "New Moon"
    }
}

// Keep old TodayView for backwards compat
struct TodayView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    var body: some View {
        TodayFeedView(diaryManager: diaryManager)
    }
}

// MARK: - Array Unique Helper

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        TodayFeedView(diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext))
    }
}
