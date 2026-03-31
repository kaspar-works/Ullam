import SwiftUI
import SwiftData

#if os(iOS)
import UIKit

struct TodayFeedMobileView: View {
    @Bindable var diaryManager: DiaryManager

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var contrast

    @State private var pages: [Page] = []
    @State private var decryptedPages: [(page: Page, title: String, body: String, emojis: [String])] = []
    @State private var isLoading = true
    @State private var selectedPage: Page?
    @State private var dayMood: String?
    @State private var showMoodPicker = false
    @State private var pageToDelete: Page?
    @State private var showDeleteConfirmation = false
    @State private var appeared = false
    @State private var fabPulse = false
    @State private var headerOffset: CGFloat = -20
    @State private var headerOpacity: Double = 0

    // Writing Prompts
    @State private var promptService: WritingPromptService?
    @State private var showFabMenu = false

    // Writing Goal
    @State private var writingGoalEnabled = false
    @State private var writingGoal = 200

    // Throwback
    @State private var throwbackEntries: [(page: Page, title: String, body: String, yearsAgo: Int)]?
    @State private var throwbackDismissed = false
    @State private var throwbackPage: Page?

    private let selectedDate = Date()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

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

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            feedBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        .offset(y: headerOffset)
                        .opacity(headerOpacity)

                    // Throwback card
                    if let entries = throwbackEntries, !entries.isEmpty, !throwbackDismissed {
                        ThrowbackCard(
                            entries: entries,
                            onTapEntry: { page in
                                throwbackPage = page
                            },
                            onDismiss: {
                                throwbackDismissed = true
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    // Writing Goal
                    if writingGoalEnabled {
                        WritingGoalCard(diaryManager: diaryManager, goal: writingGoal)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }

                    // Writing Prompt
                    if let service = promptService {
                        WritingPromptCard(
                            diaryManager: diaryManager,
                            promptService: service
                        ) { subtitle in
                            createNewPageWithSubtitle(subtitle)
                        }
                        .padding(.bottom, 16)
                    }

                    // Content
                    if isLoading {
                        loadingState
                    } else if decryptedPages.isEmpty {
                        emptyState
                    } else {
                        timelineContent
                    }
                }
                .padding(.bottom, 100)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    fabButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                }
            }
        }
        .task {
            await loadData()
            throwbackEntries = await ThrowbackService.shared.getThrowback(diaryManager: diaryManager, for: Date())
        }
        .onChange(of: diaryManager.currentDiary?.id) { _, _ in
            Task { await loadData() }
        }
        .onAppear {
            // Initialize services
            let context = DataController.shared.container.mainContext
            if promptService == nil {
                let ps = WritingPromptService(modelContext: context)
                ps.seedPromptsIfNeeded()
                promptService = ps
            }
            // Load writing goal settings
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            if let settings = try? context.fetch(settingsDescriptor).first {
                writingGoalEnabled = settings.isWritingGoalEnabled
                writingGoal = settings.dailyWordGoal
            }

            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) {
                headerOffset = 0
                headerOpacity = 1
            }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                    fabPulse = true
                }
            }
        }
        .sheet(item: $selectedPage, onDismiss: {
            Task { await loadData() }
        }) { page in
            PageEditorMobileView(diaryManager: diaryManager, page: page, date: selectedDate)
                .presentationBackground(AppTheme.bg)
        }
        .sheet(isPresented: $showMoodPicker) {
            EmojiPickerView(selectedEmoji: $dayMood) { emoji in
                dayMood = emoji
                Task { await diaryManager.setDayMood(emoji, for: selectedDate) }
                showMoodPicker = false
            }
            .presentationDetents([.medium])
            .presentationBackground(.ultraThinMaterial)
        }
        .alert("Delete Page", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { pageToDelete = nil }
            Button("Delete", role: .destructive) {
                if let page = pageToDelete { deletePage(page) }
            }
        } message: {
            Text("Are you sure you want to delete this page? This action cannot be undone.")
        }
        .sheet(item: $throwbackPage) { page in
            PageEditorMobileView(diaryManager: diaryManager, page: page, date: page.date)
                .presentationBackground(AppTheme.bg)
        }
    }

    // MARK: - Background

    private var feedBackground: some View {
        ZStack {
            AppTheme.bg

            RadialGradient(
                colors: [AppTheme.accent.opacity(0.05), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 350
            )

            RadialGradient(
                colors: [AppTheme.gradientPink.opacity(0.03), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date
            Text(formattedDate)
                .font(.custom("NewYork-Bold", size: 30, relativeTo: .largeTitle))
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
                .lineLimit(2)

            // Mood row
            Button { showMoodPicker = true } label: {
                HStack(spacing: 8) {
                    if let mood = dayMood {
                        Text(mood)
                            .font(.system(size: 20))
                            .transition(.scale.combined(with: .opacity))

                        Text("Today\u{2019}s mood")
                            .font(.system(.subheadline, design: .default))
                            .foregroundStyle(AppTheme.dimText)
                    } else {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(fabPulse ? 0.18 : 0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: "face.smiling")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.accent)
                        }

                        Text("How are you feeling?")
                            .font(.system(.subheadline, design: .default))
                            .foregroundStyle(AppTheme.accent.opacity(0.7))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.dimText)
                }
            }
            .buttonStyle(FeedButtonStyle())
            .accessibilityLabel(dayMood != nil ? "Today's mood: \(dayMood!)" : "Set today's mood")
            .accessibilityHint("Opens the mood picker")
            .accessibilityValue(dayMood ?? "No mood set")
            .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7), value: dayMood)
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedByDay.enumerated()), id: \.element.date) { groupIdx, group in
                // Section header
                dateSectionHeader(for: group.date)
                    .padding(.horizontal, 20)
                    .padding(.top, groupIdx == 0 ? 0 : 24)
                    .padding(.bottom, 12)

                // Entry cards with timeline
                ForEach(Array(group.entries.enumerated()), id: \.element.page.id) { entryIdx, entry in
                    let globalIdx = globalIndex(groupIdx: groupIdx, entryIdx: entryIdx)
                    let isLast = entryIdx == group.entries.count - 1

                    timelineEntry(entry: entry, isLast: isLast)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(
                            reduceMotion ? .none :
                            .spring(response: 0.45, dampingFraction: 0.8)
                            .delay(Double(globalIdx) * 0.06),
                            value: appeared
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                pageToDelete = entry.page
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Page", systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, isLast ? 8 : 4)
                }
            }
        }
    }

    // MARK: - Timeline Entry (with connector line)

    private func timelineEntry(entry: (page: Page, title: String, body: String, emojis: [String]), isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline column
            VStack(spacing: 0) {
                // Time label
                Text(formatTime(entry.page.createdAt))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.dimText)
                    .frame(width: 48)

                // Dot
                Circle()
                    .fill(
                        entry.emojis.isEmpty ?
                        AppTheme.mutedText.opacity(0.3) :
                        AppTheme.accent.opacity(0.5)
                    )
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
                    .scaleEffect(appeared ? 1 : 0)
                    .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6).delay(0.2), value: appeared)

                // Connector line
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.mutedText.opacity(0.2), AppTheme.mutedText.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 48)

            // Card
            Button {
                selectedPage = entry.page
            } label: {
                entryCard(entry: entry)
            }
            .buttonStyle(FeedCardButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.title.isEmpty ? "Untitled Entry" : entry.title), \(formatTime(entry.page.createdAt))")
            .accessibilityHint("Opens this entry for editing")
        }
    }

    // MARK: - Entry Card

    private func entryCard(entry: (page: Page, title: String, body: String, emojis: [String])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + emojis
            HStack(alignment: .top) {
                Text(entry.title.isEmpty ? "Untitled Entry" : entry.title)
                    .font(.custom("NewYork-Bold", size: 17, relativeTo: .headline))
                    .foregroundStyle(entry.title.isEmpty ? AppTheme.dimText : AppTheme.primaryText)
                    .lineLimit(2)

                Spacer()

                if !entry.emojis.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(entry.emojis, id: \.self) { e in
                            Text(e).font(.system(size: 14))
                        }
                    }
                }
            }

            // Body preview
            if !entry.body.isEmpty {
                Text(String(entry.body.prefix(160)))
                    .font(.system(.body, design: .default))
                    .foregroundStyle(AppTheme.mutedText)
                    .lineSpacing(5)
                    .lineLimit(4)
            } else {
                Text("Tap to start writing\u{2026}")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(AppTheme.dimText)
                    .italic()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBg)
                .shadow(color: AppTheme.primaryText.opacity(0.04), radius: 8, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.mutedText.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.bottom, 14)
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            createNewPage()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // Breathing outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(fabPulse ? 0.3 : 0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: fabPulse ? 45 : 35
                        )
                    )
                    .frame(width: 80, height: 80)

                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 70, height: 70)

                // Button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, Color(hex: 0xC49340)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.accent.opacity(fabPulse ? 0.45 : 0.25), radius: fabPulse ? 20 : 12, y: 6)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.subtle, lineWidth: 1)
                    )

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .rotationEffect(.degrees(appeared ? 0 : 90))
            }
            .scaleEffect(fabPulse ? 1.04 : 1.0)
        }
        .buttonStyle(FeedButtonStyle())
        .accessibilityLabel("New page")
        .accessibilityHint("Creates a new diary entry")
        .frame(minWidth: 56, minHeight: 56)
        .contentShape(Rectangle())
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.5)
        .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: appeared)
    }

    // MARK: - Section Header

    private func dateSectionHeader(for date: Date) -> some View {
        let cal = Calendar.current
        let label: String
        if cal.isDateInToday(date) { label = "Today" }
        else if cal.isDateInYesterday(date) { label = "Yesterday" }
        else {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMMM d"
            label = f.string(from: date)
        }

        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.mutedText)
                .accessibilityAddTraits(.isHeader)

            Rectangle()
                .fill(AppTheme.mutedText.opacity(contrast == .increased ? 0.2 : 0.1))
                .frame(height: 1)
                .scaleEffect(x: appeared ? 1 : 0, anchor: .leading)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.1), value: appeared)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(fabPulse ? 0.1 : 0.04))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(AppTheme.accent.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: "text.book.closed")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.accent.opacity(0.4))
                    .scaleEffect(fabPulse ? 1.05 : 1.0)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.6)
            .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: appeared)

            VStack(spacing: 6) {
                Text("Your story starts here")
                    .font(.custom("NewYork-Bold", size: 20, relativeTo: .title3))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Tap + to write your first page today")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(AppTheme.mutedText)
                    .lineLimit(2)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.5).delay(0.35), value: appeared)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.dimText)
            Text("Loading your pages\u{2026}")
                .font(.system(.caption, design: .default))
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func globalIndex(groupIdx: Int, entryIdx: Int) -> Int {
        var idx = 0
        for i in 0..<groupIdx {
            idx += groupedByDay[i].entries.count
        }
        return idx + entryIdx
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        pages = diaryManager.getRecentPages(days: 14)

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
        // If there's already an empty page for today, open it instead of creating a new one
        let cal = Calendar.current
        if let existingEmpty = decryptedPages.first(where: { entry in
            cal.isDateInToday(entry.page.createdAt) &&
            entry.title.isEmpty &&
            entry.body.isEmpty
        }) {
            selectedPage = existingEmpty.page
            return
        }

        if let newPage = diaryManager.createPage(for: selectedDate) {
            selectedPage = newPage
        }
    }

    private func createNewPageWithSubtitle(_ subtitle: String) {
        if let newPage = diaryManager.createPage(for: selectedDate) {
            newPage.subtitle = subtitle
            try? DataController.shared.container.mainContext.save()
            selectedPage = newPage
        }
    }

    private func deletePage(_ page: Page) {
        pages.removeAll { $0.id == page.id }
        decryptedPages.removeAll { $0.page.id == page.id }
        diaryManager.deletePage(page)
        pageToDelete = nil
    }
}

// MARK: - Button Styles

private struct FeedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct FeedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        TodayFeedMobileView(diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext))
    }
}
#endif // os(iOS)
