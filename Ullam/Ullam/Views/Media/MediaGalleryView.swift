import SwiftUI
import SwiftData

struct MediaGalleryView: View {
    @State private var selectedFilter: MediaFilter = .all
    @State private var imageAttachments: [MediaAttachment] = []
    @State private var audioAttachments: [MediaAttachment] = []
    @State private var allAttachments: [MediaAttachment] = []

    enum MediaFilter: String, CaseIterable {
        case all = "All Media"
        case images = "Images"
        case videos = "Videos"
        case audio = "Audio"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Filter tabs
                filterTabs
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Captured Moments
                capturedMomentsSection
                    .padding(.bottom, 32)

                // Vocal Echoes
                vocalEchoesSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .task { loadAttachments() }
    }

    // MARK: - Data Loading

    private func loadAttachments() {
        let context = DataController.shared.container.mainContext

        // Fetch all media sorted by createdAt descending
        var descriptor = FetchDescriptor<MediaAttachment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        allAttachments = all
        imageAttachments = all.filter { $0.mediaType == .image || $0.mediaType == .video }
        audioAttachments = all.filter { $0.mediaType == .audio }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(MediaFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 12, weight: selectedFilter == filter ? .semibold : .regular))
                        .foregroundStyle(selectedFilter == filter ? .white : AppTheme.mutedText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedFilter == filter ?
                            Capsule().fill(AppTheme.accent.opacity(0.25)) :
                            Capsule().fill(Color.clear)
                        )
                        .overlay(
                            selectedFilter == filter ?
                            Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1) :
                            Capsule().stroke(AppTheme.subtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
    }

    // MARK: - Captured Moments

    private var capturedMomentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Captured Moments")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("\(imageAttachments.count) ITEMS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.mutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(AppTheme.subtle)
                    )

                Spacer()

                Button {} label: {
                    Text("View Gallery")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            if imageAttachments.isEmpty {
                emptyStateView(icon: "photo", message: "No photos yet")
                    .padding(.horizontal, 24)
            } else {
                photoGrid
            }
        }
    }

    private var photoGrid: some View {
        let visibleImages = Array(imageAttachments.prefix(6))
        let col1 = visibleImages.enumerated().filter { $0.offset % 3 == 0 }.map(\.element)
        let col2 = visibleImages.enumerated().filter { $0.offset % 3 == 1 }.map(\.element)
        let col3 = visibleImages.enumerated().filter { $0.offset % 3 == 2 }.map(\.element)
        let heights: [CGFloat] = [380, 340, 300, 280, 320, 360]

        return HStack(alignment: .top, spacing: 10) {
            // Column 1
            VStack(spacing: 10) {
                ForEach(Array(col1.enumerated()), id: \.element.id) { idx, attachment in
                    mediaThumbnail(attachment: attachment, height: heights[idx * 3 % heights.count])
                }
            }

            // Column 2
            VStack(spacing: 10) {
                ForEach(Array(col2.enumerated()), id: \.element.id) { idx, attachment in
                    mediaThumbnail(attachment: attachment, height: heights[(idx * 3 + 1) % heights.count])
                }
            }

            // Column 3
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 10) {
                    ForEach(Array(col3.enumerated()), id: \.element.id) { idx, attachment in
                        mediaThumbnail(attachment: attachment, height: heights[(idx * 3 + 2) % heights.count])
                    }
                }

                // Floating add button
                Button {} label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.7))
                            .frame(width: 48, height: 48)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
        .padding(.horizontal, 24)
    }

    private func mediaThumbnail(attachment: MediaAttachment, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AppTheme.subtle)
            .frame(height: height)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: attachment.mediaType == .video ? "video.fill" : "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.dimText)
                    Text(attachment.fileName)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.dimText)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.subtle, lineWidth: 1)
            )
    }

    // MARK: - Vocal Echoes

    private var vocalEchoesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Vocal Echoes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("\(audioAttachments.count) ECHOES")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.mutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.subtle))
            }

            if audioAttachments.isEmpty {
                emptyStateView(icon: "waveform", message: "No audio yet")
            } else {
                HStack(spacing: 12) {
                    ForEach(Array(audioAttachments.prefix(2)), id: \.id) { attachment in
                        audioCard(attachment: attachment)
                    }
                }
            }
        }
    }

    private func audioCard(attachment: MediaAttachment) -> some View {
        let dateString: String = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: attachment.createdAt)
        }()

        return HStack(spacing: 12) {
            // Play button
            Button {} label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.subtle)
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.fileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Text(dateString)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.dimText)
                    .lineLimit(1)
            }

            Spacer()

            // Waveform
            waveform
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )
        )
    }

    private var waveform: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { i in
                let heights: [CGFloat] = [0.3, 0.5, 0.7, 0.9, 0.6, 0.8, 0.4, 0.7, 0.5, 0.9, 0.6, 0.3]
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppTheme.dimText)
                    .frame(width: 2, height: 16 * heights[i])
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.dimText)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.subtle)
        )
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        MediaGalleryView()
    }
}
