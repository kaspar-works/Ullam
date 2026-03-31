import SwiftUI
import SwiftData

// MARK: - Shared Theme

enum AppTheme {
    // Backgrounds
    static let bg = Color(light: Color(hex: 0xF2EDE3), dark: Color(hex: 0x1F2433))
    static let sidebarBg = Color(light: Color(hex: 0xE8E2D6), dark: Color(hex: 0x2F3A55))
    static let cardBg = Color(light: Color(hex: 0xFAF7F1), dark: Color(hex: 0x283044))
    static let cardSurface = Color(light: .white, dark: Color(hex: 0x2F3A55))

    // Primary Gradient Colors
    static let gradientBlue = Color(hex: 0x2F3A55)      // Accent Blue
    static let gradientPurple = Color(hex: 0xD4A24C)     // Gold
    static let gradientPink = Color(hex: 0xF2EDE3)       // Cream

    // Primary accent
    static let accent = Color(light: Color(hex: 0xC49340), dark: Color(hex: 0xD4A24C))
    static let indigo = Color(light: Color(hex: 0x2F3A55), dark: Color(hex: 0x4A5A7A))

    // Neutral / Secondary
    static let sage = Color(light: Color(hex: 0x6B7080), dark: Color(hex: 0x8890A0))
    static let coolGray = Color(hex: 0xB0B5C0)

    // Semantic text colors
    static let primaryText = Color(light: Color(hex: 0x1F2433), dark: Color(hex: 0xF2EDE3))
    static let secondaryText = Color(light: Color(hex: 0x3A4050), dark: Color(hex: 0xD0CABC))

    // Text helpers
    static let subtle = Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.07))
    static let dimText = Color(light: Color(hex: 0x8A8E98), dark: Color(hex: 0x6B7080))
    static let mutedText = Color(light: Color(hex: 0x6B7080), dark: Color(hex: 0x8890A0))

    // Emotion colors
    static let moodHappy = Color(hex: 0xD4A24C)          // Gold
    static let moodCalm = Color(hex: 0x5B8A72)           // Forest Sage
    static let moodSad = Color(hex: 0x7080AA)            // Muted Blue
    static let moodLove = Color(hex: 0xC07070)           // Dusty Rose
    static let moodNeutral = Color(hex: 0xC8C3B8)        // Warm Gray

    // Brand gradient
    static let brandGradient = LinearGradient(
        colors: [gradientBlue, gradientPurple, gradientPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Adaptive Color Helper

extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(dark) : NSColor(light)
        })
        #else
        self = dark
        #endif
    }
}

// MARK: - Color Hex Extension

// MARK: - Theme Mode Helper

enum AppThemeHelper {
    static var preferredScheme: ColorScheme? {
        let raw = UserDefaults.standard.string(forKey: "appThemeMode") ?? "system"
        switch raw {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // system
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Main Layout

struct MainTabView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var selectedTab: SidebarTab = .diaries
    @State private var selectedDate: Date = Date()
    @State private var currentPage: Page?
    @State private var pages: [Page] = []
    @State private var dayMood: String?
    @State private var isLoading: Bool = true
    @State private var showingMoodPicker: Bool = false
    @State private var showSearch: Bool = false
    @State private var searchQuery: String = ""
    @State private var todayWordCount: Int = 0
    @State private var dailyGoal: Int = 200
    @State private var recentMedia: [MediaAttachment] = []

    enum SidebarTab: String, CaseIterable {
        case today = "Today"
        case calendar = "Calendar"
        case diaries = "Diaries"
        case media = "Media"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .today: return "square.and.pencil"
            case .calendar: return "calendar"
            case .diaries: return "text.book.closed"
            case .media: return "photo.on.rectangle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        Group {
            #if os(iOS)
            iOSLayout
            #else
            macOSLayout
            #endif
        }
        .background(AppTheme.bg)
        .preferredColorScheme(AppThemeHelper.preferredScheme)
        .onAppear { loadPages() }
        .onChange(of: diaryManager.currentDiary?.id) { _, _ in loadPages() }
        .sheet(isPresented: $showingMoodPicker) {
            EmojiPickerView(selectedEmoji: $dayMood) { emoji in
                Task {
                    await diaryManager.setDayMood(emoji, for: selectedDate)
                    showingMoodPicker = false
                }
            }
            #if os(iOS)
            .presentationDetents([.medium])
            #endif
        }
        .sheet(isPresented: $showSearch) {
            SearchView(diaryManager: diaryManager)
                #if os(iOS)
                .presentationDetents([.large])
                #else
                .frame(minWidth: 500, minHeight: 400)
                #endif
        }
    }

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayFeedMobileView(diaryManager: diaryManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Ullam")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            quickLockButton
                        }
                    }
            }
            .tabItem { Label("Today", systemImage: "square.and.pencil") }
            .tag(SidebarTab.today)

            NavigationStack {
                CalendarMobileView(diaryManager: diaryManager)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Ullam")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            quickLockButton
                        }
                    }
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(SidebarTab.calendar)

            NavigationStack {
                DiariesMobileView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Ullam")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            quickLockButton
                        }
                    }
            }
            .tabItem { Label("Diaries", systemImage: "text.book.closed") }
            .tag(SidebarTab.diaries)

            NavigationStack {
                MediaMobileView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("ULLAM")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(AppTheme.sage)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            quickLockButton
                        }
                    }
            }
            .tabItem { Label("Media", systemImage: "photo.on.rectangle") }
            .tag(SidebarTab.media)

            NavigationStack {
                SettingsMobileView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(SidebarTab.settings)
        }
        .tint(AppTheme.accent)
    }

    /// Quick Lock button -- only visible when the current diary is protected.
    @ViewBuilder
    private var quickLockButton: some View {
        if diaryManager.currentDiary?.isProtected == true {
            Button {
                PanicLockService.shared.performPanicLock(diaryManager: diaryManager)
            } label: {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.indigo.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.indigo.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.indigo.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }
    #endif

    // MARK: - macOS Layout

    private var macOSLayout: some View {
        HStack(spacing: 0) {
            leftSidebar
                .frame(width: 190)

            centerContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Left Sidebar

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Midnight Paper")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("THE NOCTURNAL\nSANCTUARY")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.dimText)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 28)

            // Navigation items
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Atmosphere widget
            VStack(alignment: .leading, spacing: 8) {
                Text("Atmosphere")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)

                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent.opacity(0.7))

                    GeometryReader { geo in
                        let volume = ambienceVolume
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.subtle)
                                .frame(height: 4)
                            Capsule()
                                .fill(AppTheme.accent.opacity(0.6))
                                .frame(width: geo.size.width * volume, height: 4)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 20)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.subtle)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // User profile
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.5), AppTheme.accent.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("J")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(diaryManager.currentDiary?.name ?? "Me & Me")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Private Diary")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.dimText)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebarBg)
    }

    private func sidebarButton(_ tab: SidebarTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }

            switch tab {
            case .settings:
                break // TODO: navigate to settings
            case .today, .diaries:
                selectedDate = Date()
                loadPages()
            default:
                break
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                    .foregroundStyle(selectedTab == tab ? .white : AppTheme.mutedText)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? .white : AppTheme.mutedText)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? AppTheme.accent.opacity(0.2) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .calendar:
                CalendarYearView(diaryManager: diaryManager)

            case .settings:
                settingsTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                SettingsView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)

            case .diaries:
                diariesTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                DiariesGalleryView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)

            case .media:
                mediaTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                MediaGalleryView()

            default:
                // Today feed
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                TodayFeedView(diaryManager: diaryManager)
            }
        }
    }

    private var mediaTopBar: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Media")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("VISUAL MEMORIES & ECHOES")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()

            Button {
                showSearch = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                    Text("Search your memories...")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.subtle))
            }
            .buttonStyle(.plain)

            Spacer().frame(width: 16)

            HStack(spacing: 14) {
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Text("Upload")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var settingsTopBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                Text("Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)

                Text("General")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .underline()

                Text("Sync")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()

            Button {
                showSearch = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                    Text("Search settings...")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.subtle))
            }
            .buttonStyle(.plain)

            Spacer().frame(width: 16)

            HStack(spacing: 14) {
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var diariesTopBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                Text("My Collections")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)

                Text("Diaries")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .underline()

                Text("Shared")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()

            // Search
            Button {
                showSearch = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                    Text("Search entries...")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.subtle))
            }
            .buttonStyle(.plain)

            Spacer().frame(width: 16)

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                    Text("SYNC")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(AppTheme.mutedText)

                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)

                Button { showPincodeOverlay = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            // Tabs
            HStack(spacing: 16) {
                Text("Today")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Button {
                    createNewPage()
                } label: {
                    Text("New Entry")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .underline()
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Text("Sync")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.dimText)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Search
            Button {
                showSearch = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                    Text("Search archives...")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(AppTheme.subtle)
                )
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(width: 16)

            // Actions
            HStack(spacing: 14) {
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)

                Button {
                    showPincodeOverlay = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.dimText)
            Text("No pages yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
            Text("Create your first page for today")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
            Button {
                createNewPage()
            } label: {
                Text("New Page")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Right Sidebar

    private var rightSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Entry Media
                VStack(alignment: .leading, spacing: 12) {
                    Text("ENTRY MEDIA")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.mutedText)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        if recentMedia.isEmpty {
                            // Empty state
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.subtle)
                                .aspectRatio(1.2, contentMode: .fit)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 16))
                                        Text("No media")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundStyle(AppTheme.dimText)
                                )
                        } else {
                            ForEach(recentMedia, id: \.id) { attachment in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.subtle)
                                    .aspectRatio(1.2, contentMode: .fit)
                                    .overlay(
                                        VStack(spacing: 4) {
                                            Image(systemName: attachment.mediaType == .audio ? "waveform" : (attachment.mediaType == .video ? "video.fill" : "photo"))
                                                .font(.system(size: 16))
                                                .foregroundStyle(AppTheme.dimText)
                                            Text(attachment.fileName)
                                                .font(.system(size: 8))
                                                .foregroundStyle(AppTheme.dimText)
                                                .lineLimit(1)
                                                .padding(.horizontal, 4)
                                        }
                                    )
                            }
                        }

                        // Add media button
                        Button {} label: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.subtle)
                                .aspectRatio(1.2, contentMode: .fit)
                                .overlay(
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 18))
                                        Text("Add Media")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundStyle(AppTheme.dimText)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Emotional Pulse
                VStack(alignment: .leading, spacing: 12) {
                    Text("EMOTIONAL PULSE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.mutedText)

                    moodButton(emoji: "🌙", label: "Reflective", isSelected: dayMood == "🌙") {
                        Task {
                            dayMood = "🌙"
                            await diaryManager.setDayMood("🌙", for: selectedDate)
                        }
                    }

                    moodButton(emoji: "🌿", label: "Calm", isSelected: dayMood == "🌿") {
                        Task {
                            dayMood = "🌿"
                            await diaryManager.setDayMood("🌿", for: selectedDate)
                        }
                    }

                    moodButton(emoji: "🌀", label: "Restless", isSelected: dayMood == "🌀") {
                        Task {
                            dayMood = "🌀"
                            await diaryManager.setDayMood("🌀", for: selectedDate)
                        }
                    }

                    Button {
                        showingMoodPicker = true
                    } label: {
                        Text("More moods...")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                // Writing Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("WRITING STATS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.mutedText)

                    VStack(spacing: 0) {
                        statRow(label: "Word Count", value: "\(todayWordCount)")
                        Divider().opacity(0.1)
                        statRow(label: "Reading Time", value: readingTimeString)
                        Divider().opacity(0.1)

                        HStack {
                            Text("Daily Goal")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.mutedText)
                            Spacer()
                            Text("\(Int(goalPercentage * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.subtle)
                                    .frame(height: 3)
                                Capsule()
                                    .fill(AppTheme.accent)
                                    .frame(width: geo.size.width * goalPercentage, height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.subtle)
                    )
                }

                Spacer(minLength: 60)

                // Preserve Entry button
                Button {} label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("Preserve Entry")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(AppTheme.accent.opacity(0.7))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebarBg)
    }

    private func moodButton(emoji: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppTheme.accent.opacity(0.15) : AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppTheme.accent.opacity(0.3) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.mutedText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    // MARK: - Computed Helpers

    private var ambienceVolume: CGFloat {
        let context = DataController.shared.container.mainContext
        let descriptor = FetchDescriptor<AppSettings>()
        let settings = try? context.fetch(descriptor)
        return CGFloat(settings?.first?.ambienceVolume ?? 0.5)
    }

    private var goalPercentage: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayWordCount) / Double(dailyGoal), 1.0)
    }

    private var readingTimeString: String {
        let minutes = max(1, todayWordCount / 200)
        return "~\(minutes) min"
    }

    // MARK: - Data

    private func loadPages() {
        isLoading = true
        pages = diaryManager.getPages(for: selectedDate)

        if let firstPage = pages.first {
            currentPage = firstPage
        } else {
            currentPage = nil
        }

        // Compute today's word count from plaintext content
        var words = 0
        for page in pages {
            if let content = page.plaintextContent {
                let text = (try? NSAttributedString(
                    data: content,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ).string) ?? String(data: content, encoding: .utf8) ?? ""
                words += text.split(separator: " ").count
            }
        }
        todayWordCount = words

        // Load daily goal from settings
        let context = DataController.shared.container.mainContext
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            dailyGoal = settings.dailyWordGoal > 0 ? settings.dailyWordGoal : 200
        }

        // Load recent media attachments
        var mediaDescriptor = FetchDescriptor<MediaAttachment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        mediaDescriptor.fetchLimit = 4
        recentMedia = (try? context.fetch(mediaDescriptor)) ?? []

        Task {
            if let mood = diaryManager.getDayMood(for: selectedDate) {
                dayMood = await diaryManager.decryptDayMood(mood)
            } else {
                dayMood = nil
            }
            isLoading = false
        }
    }

    private func createNewPage() {
        if let newPage = diaryManager.createPage(for: selectedDate) {
            pages.insert(newPage, at: 0)
            currentPage = newPage
        }
    }
}

#Preview {
    MainTabView(
        diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext),
        showPincodeOverlay: .constant(false)
    )
}
