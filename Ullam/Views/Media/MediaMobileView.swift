#if os(iOS)
import SwiftUI
import UIKit

struct MediaMobileView: View {
    @State private var selectedTab: MediaTab = .photos
    @State private var activeSubFilter: String? = nil
    @State private var appeared = false
    @State private var playingIndex: Int? = nil

    enum MediaTab: String, CaseIterable {
        case photos = "Photos"
        case videos = "Videos"
        case audio = "Audio"

        var icon: String {
            switch self {
            case .photos: return "photo.fill"
            case .videos: return "video.fill"
            case .audio: return "waveform"
            }
        }
    }

    private let subFilters: [(icon: String, label: String)] = [
        ("book.closed", "All Diaries"),
        ("calendar", "Date"),
        ("heart", "Emotion"),
    ]

    var body: some View {
        ZStack {
            mediaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    // Tab selector
                    tabSelector
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    // Sub-filters
                    subFilterChips
                        .padding(.bottom, 18)

                    // Content
                    switch selectedTab {
                    case .photos:
                        photoGrid
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                    case .videos:
                        videoGrid
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                    case .audio:
                        audioSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                    }

                    // Voice Diaries (always visible)
                    if selectedTab != .audio {
                        voiceDiariesSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }

                    Spacer(minLength: 100)
                }
            }

            // Quick capture FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    quickCaptureFAB
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var mediaBackground: some View {
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Media Library")
                .font(.custom("NewYork-Bold", size: 28, relativeTo: .largeTitle))
                .foregroundStyle(.white)

            Text("Your captured moments, beautifully preserved.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Tab Selector (pill segmented control)

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(MediaTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.35))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(
                                selectedTab == tab ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [AppTheme.accent.opacity(0.35), Color(hex: 0x7C3AED).opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )) :
                                AnyShapeStyle(.white.opacity(0.03))
                            )
                    )
                    .shadow(color: selectedTab == tab ? AppTheme.accent.opacity(0.15) : .clear, radius: 8, y: 2)
                }
                .buttonStyle(MediaButtonStyle())
            }
            Spacer()
        }
    }

    // MARK: - Sub-filter Chips

    private var subFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subFilters, id: \.label) { filter in
                    let isActive = activeSubFilter == filter.label
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            activeSubFilter = isActive ? nil : filter.label
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 10, weight: .medium))
                            Text(filter.label)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(isActive ? .white.opacity(0.7) : .white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isActive ? .white.opacity(0.08) : .white.opacity(0.03))
                                .overlay(
                                    Capsule()
                                        .stroke(isActive ? .white.opacity(0.12) : .white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(MediaButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        let items: [(gradient: (Color, Color), label: String, date: String, tag: String?)] = [
            ((Color(hex: 0x332D5C), Color(hex: 0x14142E)), "Evening walk", "Mar 24", "Calm"),
            ((Color(hex: 0x7A5C33), Color(hex: 0x3D2814)), "Golden hour", "Mar 23", nil),
            ((Color(hex: 0x264D5C), Color(hex: 0x0D1F2E)), "Morning mist", "Mar 22", "Reflective"),
            ((Color(hex: 0x5C4428), Color(hex: 0x28190E)), "Coffee ritual", "Mar 21", nil),
            ((Color(hex: 0x3D2D5C), Color(hex: 0x1A1433)), "Night sky", "Mar 20", "Deep"),
            ((Color(hex: 0x2D4A3D), Color(hex: 0x14281A)), "Garden", "Mar 19", nil),
        ]

        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                mediaCard(
                    gradient: item.gradient,
                    label: item.label,
                    date: item.date,
                    tag: item.tag,
                    height: idx == 0 ? 200 : (idx % 3 == 0 ? 180 : 150),
                    icon: "photo.fill"
                )
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.95)
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.8)
                    .delay(Double(idx) * 0.06),
                    value: appeared
                )
            }
        }
    }

    // MARK: - Video Grid

    private var videoGrid: some View {
        let items: [(gradient: (Color, Color), label: String, date: String, duration: String)] = [
            ((Color(hex: 0x2D3D5C), Color(hex: 0x141D2E)), "River walk", "Mar 24", "2:34"),
            ((Color(hex: 0x5C3D4A), Color(hex: 0x2E1420)), "Sunset", "Mar 22", "0:45"),
        ]

        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    ZStack(alignment: .bottomLeading) {
                        mediaCard(
                            gradient: item.gradient,
                            label: item.label,
                            date: item.date,
                            tag: nil,
                            height: 170,
                            icon: "video.fill"
                        )

                        // Duration badge
                        Text(item.duration)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(12)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(idx) * 0.06), value: appeared)
                }
            }

            if items.count <= 2 {
                emptyHint(message: "Record moments to see them here")
            }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            voiceDiariesContent
        }
    }

    // MARK: - Media Card

    private func mediaCard(
        gradient: (Color, Color),
        label: String,
        date: String,
        tag: String?,
        height: CGFloat,
        icon: String
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [gradient.0, gradient.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )

            // Overlay info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let tag {
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Spacer()

                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Text(date)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(12)
        }
    }

    // MARK: - Voice Diaries Section

    private var voiceDiariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent.opacity(0.6))
                Text("Voice Diaries")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.leading, 4)

            voiceDiariesContent
        }
    }

    private var voiceDiariesContent: some View {
        let entries: [(title: String, date: String, duration: String)] = [
            ("Midnight Thoughts", "Oct 23", "3:44"),
            ("Rainy Morning Session", "Oct 4", "1:10"),
            ("Evening Reflection", "Sep 28", "5:22"),
        ]

        return VStack(spacing: 8) {
            ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                voiceCard(
                    title: entry.title,
                    date: entry.date,
                    duration: entry.duration,
                    index: idx
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.8)
                    .delay(0.2 + Double(idx) * 0.06),
                    value: appeared
                )
            }
        }
    }

    private func voiceCard(title: String, date: String, duration: String, index: Int) -> some View {
        let isPlaying = playingIndex == index

        return Button {
            withAnimation(.spring(response: 0.3)) {
                playingIndex = isPlaying ? nil : index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Play button
                    ZStack {
                        Circle()
                            .fill(isPlaying ? AppTheme.accent.opacity(0.15) : .white.opacity(0.04))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(isPlaying ? AppTheme.accent.opacity(0.3) : .white.opacity(0.06), lineWidth: 1)
                            )

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isPlaying ? AppTheme.accent : .white.opacity(0.5))
                    }
                    .shadow(color: isPlaying ? AppTheme.accent.opacity(0.2) : .clear, radius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("RECORDED \(date.uppercased()) \u{00B7} \(duration)")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.2))
                    }

                    Spacer()

                    // Waveform
                    HStack(spacing: 2) {
                        ForEach(0..<12, id: \.self) { i in
                            let heights: [CGFloat] = [0.3, 0.5, 0.8, 0.4, 1.0, 0.6, 0.9, 0.3, 0.7, 0.5, 0.8, 0.4]
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isPlaying ? AppTheme.accent.opacity(0.5) : .white.opacity(0.12))
                                .frame(width: 2, height: 16 * heights[i])
                        }
                    }
                }

                // Progress bar (when playing)
                if isPlaying {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.06))
                                .frame(height: 3)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.gradientPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * 0.35, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPlaying ? AppTheme.accent.opacity(0.04) : .white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isPlaying ? AppTheme.accent.opacity(0.12) : .white.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(color: isPlaying ? AppTheme.accent.opacity(0.08) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(MediaButtonStyle())
    }

    // MARK: - Quick Capture FAB

    private var quickCaptureFAB: some View {
        Menu {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Record Audio", systemImage: "mic.fill")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Add from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, Color(hex: 0x7C3AED)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 16, y: 6)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Empty Hint

    private func emptyHint(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "film")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.12))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - Button Style

private struct MediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#endif // os(iOS)
