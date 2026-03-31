#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct MediaMobileView: View {
    @State private var selectedTab: MediaTab = .photos
    @State private var activeSubFilter: String? = nil
    @State private var appeared = false
    @State private var playingIndex: Int? = nil
    @State private var fabPulse = false
    @State private var contentId = UUID()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

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

                    // Content with tab transition
                    Group {
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
                    }
                    .id(contentId)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)),
                        removal: .opacity
                    ))

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
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                    fabPulse = true
                }
            }
        }
    }

    // MARK: - Background

    private var mediaBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.bg,
                    AppTheme.bg,
                    AppTheme.sidebarBg,
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
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Your captured moments, beautifully preserved.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -15)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: appeared)
    }

    // MARK: - Tab Selector (pill segmented control)

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(MediaTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                        contentId = UUID()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selectedTab == tab ? AppTheme.primaryText : AppTheme.mutedText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(
                                selectedTab == tab ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [AppTheme.accent.opacity(0.35), Color(hex: 0xC49340).opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )) :
                                AnyShapeStyle(AppTheme.subtle)
                            )
                    )
                    .shadow(color: selectedTab == tab ? AppTheme.accent.opacity(0.15) : .clear, radius: 8, y: 2)
                }
                .buttonStyle(MediaButtonStyle())
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityValue(selectedTab == tab ? "Selected" : "")
                .accessibilityHint("Double tap to show \(tab.rawValue.lowercased())")
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
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isActive ? AppTheme.secondaryText : AppTheme.mutedText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isActive ? AppTheme.subtle : AppTheme.subtle)
                                .overlay(
                                    Capsule()
                                        .stroke(isActive ? AppTheme.mutedText.opacity(0.18) : AppTheme.subtle, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(MediaButtonStyle())
                    .accessibilityLabel("Filter by \(filter.label)")
                    .accessibilityValue(isActive ? "Active" : "Inactive")
                    .accessibilityHint("Double tap to \(isActive ? "remove" : "apply") filter")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        let photos = fetchMedia(type: .image)
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return Group {
            if photos.isEmpty {
                emptyMediaState(icon: "photo.fill", message: "No photos yet", hint: "Attach photos to your diary entries to see them here")
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { idx, attachment in
                        realMediaCard(attachment: attachment, height: idx == 0 ? 200 : 150, icon: "photo.fill")
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.95))
                            .animation(
                                reduceMotion ? .none :
                                .spring(response: 0.45, dampingFraction: 0.8)
                                .delay(Double(idx) * 0.06),
                                value: appeared
                            )
                    }
                }
            }
        }
    }

    // MARK: - Video Grid

    private var videoGrid: some View {
        let videos = fetchMedia(type: .video)
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return Group {
            if videos.isEmpty {
                emptyMediaState(icon: "video.fill", message: "No videos yet", hint: "Record or attach videos to your entries")
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { idx, attachment in
                        realMediaCard(attachment: attachment, height: 170, icon: "video.fill")
                            .opacity(appeared ? 1 : 0)
                            .animation(reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.8).delay(Double(idx) * 0.06), value: appeared)
                    }
                }
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
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )

            // Overlay info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let tag {
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.mutedText.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.dimText)
                }

                Spacer()

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(date)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedText)
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
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.leading, 4)

            voiceDiariesContent
        }
    }

    private var voiceDiariesContent: some View {
        let audioFiles = fetchMedia(type: .audio)

        return VStack(spacing: 8) {
            if audioFiles.isEmpty {
                emptyMediaState(icon: "waveform", message: "No voice diaries yet", hint: "Record audio entries to see them here")
            } else {
                ForEach(Array(audioFiles.enumerated()), id: \.element.id) { idx, attachment in
                    let dateStr = formatMediaDate(attachment.createdAt)
                    voiceCard(
                        title: attachment.fileName.replacingOccurrences(of: "_", with: " ")
                            .replacingOccurrences(of: ".m4a", with: "")
                            .replacingOccurrences(of: ".mp3", with: ""),
                        date: dateStr,
                        duration: "",
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
                            .fill(isPlaying ? AppTheme.accent.opacity(0.15) : AppTheme.subtle)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(isPlaying ? AppTheme.accent.opacity(0.3) : AppTheme.subtle, lineWidth: 1)
                            )

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isPlaying ? AppTheme.accent : AppTheme.mutedText)
                    }
                    .shadow(color: isPlaying ? AppTheme.accent.opacity(0.2) : .clear, radius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("RECORDED \(date.uppercased()) \u{00B7} \(duration)")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(AppTheme.dimText)
                    }

                    Spacer()

                    // Waveform (animated when playing)
                    HStack(spacing: 2) {
                        ForEach(0..<12, id: \.self) { i in
                            let heights: [CGFloat] = [0.3, 0.5, 0.8, 0.4, 1.0, 0.6, 0.9, 0.3, 0.7, 0.5, 0.8, 0.4]
                            let animatedHeight = isPlaying ? heights[(i + (playingIndex ?? 0)) % heights.count] : heights[i]
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isPlaying ? AppTheme.accent.opacity(0.5) : AppTheme.subtle)
                                .frame(width: 2, height: 16 * animatedHeight)
                                .animation(
                                    reduceMotion ? .none :
                                    (isPlaying ?
                                    .easeInOut(duration: 0.4)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.05) :
                                    .easeOut(duration: 0.2)),
                                    value: isPlaying
                                )
                        }
                    }
                    .accessibilityHidden(true)
                }

                // Progress bar (when playing)
                if isPlaying {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.subtle)
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
                    .fill(isPlaying ? AppTheme.accent.opacity(0.04) : AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isPlaying ? AppTheme.accent.opacity(0.12) : AppTheme.subtle, lineWidth: 1)
                    )
            )
            .shadow(color: isPlaying ? AppTheme.accent.opacity(0.08) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(MediaButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), recorded \(date), \(duration)")
        .accessibilityValue(isPlaying ? "Playing" : "Paused")
        .accessibilityHint("Double tap to \(isPlaying ? "pause" : "play")")
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
                // Breathing outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(fabPulse ? 0.25 : 0.1), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: fabPulse ? 45 : 35
                        )
                    )
                    .frame(width: 80, height: 80)

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
            }
            .scaleEffect(reduceMotion ? 1.0 : (fabPulse ? 1.04 : 1.0))
        }
        .accessibilityLabel("Quick capture")
        .accessibilityHint("Double tap to open capture menu")
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.5))
        .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: appeared)
    }

    // MARK: - Empty Hint

    private func emptyHint(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "film")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.mutedText)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Real Data Helpers

    private func fetchMedia(type: MediaType) -> [MediaAttachment] {
        let context = DataController.shared.container.mainContext
        let descriptor = FetchDescriptor<MediaAttachment>(
            predicate: #Predicate { $0.mediaType == type },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func realMediaCard(attachment: MediaAttachment, height: CGFloat, icon: String) -> some View {
        let dateStr = formatMediaDate(attachment.createdAt)

        return ZStack(alignment: .bottomLeading) {
            // Try to load thumbnail or show placeholder
            if let thumbName = attachment.thumbnailFileName,
               let image = loadImage(named: thumbName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if attachment.mediaType == .image,
                      let image = loadImage(named: attachment.fileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.sidebarBg)
                    .frame(height: height)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.dimText)
                    )
            }

            // Info overlay
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(attachment.fileName
                    .replacingOccurrences(of: "_", with: " ")
                    .components(separatedBy: ".").first ?? "Media")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(radius: 4)
                Text(dateStr)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(radius: 4)
            }
            .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.subtle, lineWidth: 1)
        )
    }

    private func emptyMediaState(icon: String, message: String, hint: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.dimText)
            Text(message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func loadImage(named fileName: String) -> UIImage? {
        let mediaDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Media", isDirectory: true)
        let fileURL = mediaDir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    private func formatMediaDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
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
