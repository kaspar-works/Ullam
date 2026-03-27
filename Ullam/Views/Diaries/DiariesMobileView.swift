#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct DiariesMobileView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var allDiaries: [Diary] = []
    @State private var showCreateDiary = false
    @State private var appeared = false
    @State private var recentEntries: [(page: Page, title: String, body: String)] = []
    @State private var lastWrittenAgo: String = ""
    @State private var streakDays: Int = 0
    @State private var pulseGlow = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Reflect tonight"
        }
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "\u{2600}\u{FE0F}"
        case 12..<17: return "\u{1F331}"
        case 17..<21: return "\u{1F305}"
        default: return "\u{1F319}"
        }
    }

    private var dynamicSubtitle: String {
        if streakDays > 1 {
            return "You\u{2019}re on a \(streakDays)-day streak. Keep going."
        } else if !lastWrittenAgo.isEmpty {
            return "Last wrote \(lastWrittenAgo)"
        }
        return "A place where your thoughts live and grow."
    }

    var body: some View {
        ZStack {
            diariesBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    // Current diary hero card
                    if let current = diaryManager.currentDiary {
                        heroDiaryCard(current)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
                    }

                    // Insights strip
                    if appeared {
                        insightsStrip
                            .padding(.bottom, 20)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    // Other diaries
                    ForEach(Array(otherDiaries.enumerated()), id: \.element.id) { idx, diary in
                        Button {
                            diaryManager.openDiary(diary)
                            refreshAll()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            diaryRow(diary: diary)
                        }
                        .buttonStyle(SanctuaryButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.15 + Double(idx) * 0.05), value: appeared)
                    }

                    // Recent activity
                    if !recentEntries.isEmpty && appeared {
                        recentActivitySection
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
                    }

                    Spacer().frame(height: 8)

                    // Hidden diaries
                    pincodeCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

                    // Create CTA
                    createButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)

                    // Micro text
                    Text("Start a new safe space")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 100)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
                }
            }
        }
        .onAppear {
            refreshAll()
            withAnimation { appeared = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
        .sheet(isPresented: $showCreateDiary) {
            NavigationStack {
                DiaryCreationView(diaryManager: diaryManager)
            }
            .onDisappear { refreshAll() }
        }
    }

    // MARK: - Background

    private var diariesBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0B1120),
                    Color(hex: 0x0F172A),
                    Color(hex: 0x160F2E),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Breathing glow (animated)
            RadialGradient(
                colors: [AppTheme.accent.opacity(pulseGlow ? 0.07 : 0.03), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: pulseGlow ? 380 : 320
            )

            RadialGradient(
                colors: [AppTheme.gradientPink.opacity(pulseGlow ? 0.04 : 0.02), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    // MARK: - Header (dynamic greeting)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(greeting)
                    .font(.custom("NewYork-Bold", size: 28, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                Text(greetingEmoji)
                    .font(.system(size: 24))
            }

            Text(dynamicSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .lineSpacing(3)
        }
    }

    // MARK: - Hero Diary Card

    private func heroDiaryCard(_ diary: Diary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.25), AppTheme.accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                        )

                    Image(systemName: diary.isProtected ? "lock.fill" : "text.book.closed.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("CURRENT DIARY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.accent.opacity(0.6))

                    Text(diary.name)
                        .font(.custom("NewYork-Bold", size: 22, relativeTo: .title2))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Pulsing active indicator
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x34D399).opacity(pulseGlow ? 0.2 : 0.08))
                        .frame(width: 20, height: 20)

                    Circle()
                        .fill(Color(hex: 0x34D399))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(hex: 0x34D399).opacity(0.6), radius: pulseGlow ? 6 : 3)
                }
            }
            .padding(.bottom, 14)

            // Last entry preview
            if let lastEntry = recentEntries.first {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.3))
                        .frame(width: 2, height: 30)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lastEntry.title.isEmpty ? "Untitled Entry" : lastEntry.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        Text(String(lastEntry.body.prefix(60)))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.25))
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 14)
            }

            // Metadata row
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("\((diary.pages?.count ?? 0)) entries")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.25))

                HStack(spacing: 5) {
                    Image(systemName: diary.storagePreference == .iCloud ? "icloud" : "iphone")
                        .font(.system(size: 10))
                    Text(diary.storagePreference == .iCloud ? "iCloud" : "Local")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.25))

                if !lastWrittenAgo.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(lastWrittenAgo)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.25))
                }

                Spacer()

                // Emotional tag
                Text("Reflective")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.moodCalm.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.moodCalm.opacity(0.08))
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.25),
                                    AppTheme.accent.opacity(0.08),
                                    AppTheme.gradientPink.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: AppTheme.accent.opacity(0.1), radius: 24, y: 10)
    }

    // MARK: - Insights Strip

    private var insightsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if streakDays > 0 {
                    insightChip(
                        icon: "flame.fill",
                        text: "\(streakDays)-day streak",
                        color: Color(hex: 0xFDBA74)
                    )
                }

                insightChip(
                    icon: "heart.fill",
                    text: "Most mood: Calm",
                    color: AppTheme.moodCalm
                )

                insightChip(
                    icon: "moon.fill",
                    text: "Best time: Evening",
                    color: AppTheme.accent
                )

                if let diary = diaryManager.currentDiary {
                    insightChip(
                        icon: "doc.text.fill",
                        text: "\((diary.pages?.count ?? 0)) total pages",
                        color: AppTheme.gradientPink
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func insightChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.7))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.2))
                .padding(.leading, 4)

            ForEach(Array(recentEntries.prefix(2).enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 3)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title.isEmpty ? "Untitled Entry" : entry.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)

                        if !entry.body.isEmpty {
                            Text(String(entry.body.prefix(80)))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.25))
                                .lineLimit(2)
                                .lineSpacing(3)
                        }
                    }

                    Spacer()

                    Text(relativeTime(entry.page.modifiedAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.15))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.04), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Diary Row

    private func diaryRow(diary: Diary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(.white.opacity(0.06), lineWidth: 1))
                Image(systemName: diary.isProtected ? "lock.fill" : "text.book.closed")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(diary.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\((diary.pages?.count ?? 0)) entries")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.25))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    // MARK: - Pincode Card (secure glass)

    private var pincodeCard: some View {
        Button {
            showPincodeOverlay = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.indigo.opacity(0.1))
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.indigo.opacity(0.15), lineWidth: 1)
                        )
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.indigo.opacity(0.6))
                        .shadow(color: AppTheme.indigo.opacity(0.3), radius: 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hidden Diaries")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Protected with Face ID / Passcode")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.indigo.opacity(0.35))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.indigo.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SanctuaryButtonStyle())
    }

    // MARK: - Create CTA

    private var createButton: some View {
        Button {
            showCreateDiary = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // Outer glow
                Capsule()
                    .fill(AppTheme.accent.opacity(pulseGlow ? 0.08 : 0.04))
                    .padding(-4)

                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create New Diary")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color(hex: 0x7C3AED)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, y: 8)
        }
        .buttonStyle(SanctuaryButtonStyle())
    }

    // MARK: - Helpers

    private var otherDiaries: [Diary] {
        allDiaries.filter { $0.id != diaryManager.currentDiary?.id && $0.isVisibleOnSwitch && !$0.isProtected }
    }

    private func refreshAll() {
        allDiaries = DataController.shared.fetchAllDiaries()
        Task { await loadRecentEntries() }
    }

    private func loadRecentEntries() async {
        let pages = diaryManager.getRecentPages(days: 7)
        var entries: [(page: Page, title: String, body: String)] = []
        for page in pages.prefix(3) {
            if let dec = await diaryManager.decryptPage(page) {
                let body: String
                if let data = dec.content,
                   let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                    body = attr.string
                } else { body = "" }
                entries.append((page: page, title: dec.title, body: body))
            }
        }
        recentEntries = entries

        // Calculate last written
        if let first = pages.first {
            lastWrittenAgo = relativeTime(first.modifiedAt)
        }

        // Calculate streak (simplified)
        var streak = 0
        let cal = Calendar.current
        var checkDate = Date()
        for _ in 0..<30 {
            let dayPages = diaryManager.getPages(for: checkDate)
            if dayPages.isEmpty { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        streakDays = streak
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Button Style

private struct SanctuaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#endif // os(iOS)
