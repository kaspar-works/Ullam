import SwiftUI

struct MediaGalleryView: View {
    @State private var selectedFilter: MediaFilter = .all

    enum MediaFilter: String, CaseIterable {
        case all = "All Media"
        case images = "Images"
        case videos = "Videos"
        case audio = "Audio"
        case documents = "Documents"
    }

    // Sample photo data — placeholders using gradients
    private let photoGradients: [(Color, Color)] = [
        (Color(red: 0.85, green: 0.55, blue: 0.45), Color(red: 0.35, green: 0.25, blue: 0.50)), // sunset beach
        (Color(red: 0.25, green: 0.50, blue: 0.15), Color(red: 0.15, green: 0.35, blue: 0.10)), // forest
        (Color(red: 0.30, green: 0.55, blue: 0.70), Color(red: 0.10, green: 0.20, blue: 0.35)), // mountains
        (Color(red: 0.20, green: 0.15, blue: 0.50), Color(red: 0.10, green: 0.08, blue: 0.25)), // night city
        (Color(red: 0.65, green: 0.60, blue: 0.50), Color(red: 0.40, green: 0.38, blue: 0.32)), // light room
    ]

    private let photoIcons: [String] = [
        "sun.horizon.fill", "tree.fill", "mountain.2.fill",
        "sparkles", "light.recessed"
    ]

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

                // Stationery & Archives
                stationerySection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
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
                        .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.45))
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
                            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                    .foregroundStyle(.white)

                Text("248 ITEMS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
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

            // Photo grid — masonry-like layout
            photoGrid
        }
    }

    private var photoGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            // Column 1
            VStack(spacing: 10) {
                photoCard(index: 0, height: 380)
                photoCard(index: 3, height: 280)
            }

            // Column 2
            VStack(spacing: 10) {
                photoCard(index: 1, height: 340)
                photoCard(index: 4, height: 320)
            }

            // Column 3
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 10) {
                    photoCard(index: 2, height: 300)
                    photoCard(index: 0, height: 360) // reuse gradient
                }

                // Floating add button
                Button {} label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.7))
                            .frame(width: 48, height: 48)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
        .padding(.horizontal, 24)
    }

    private func photoCard(index: Int, height: CGFloat) -> some View {
        let gradient = photoGradients[index % photoGradients.count]
        let icon = photoIcons[index % photoIcons.count]

        return RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [gradient.0, gradient.1],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: height)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
    }

    // MARK: - Vocal Echoes

    private var vocalEchoesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Vocal Echoes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("ECHOES")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.subtle))
            }

            HStack(spacing: 12) {
                audioCard(
                    title: "Dream Logic Patterns",
                    subtitle: "Midnight Thoughts · Yesterday, 2:14 AM",
                    duration: "03:42"
                )

                audioCard(
                    title: "Forest Rain Ambiance",
                    subtitle: "Nature Solitude · Oct 28, 2023",
                    duration: "12:05"
                )
            }
        }
    }

    private func audioCard(title: String, subtitle: String, duration: String) -> some View {
        HStack(spacing: 12) {
            // Play button
            Button {} label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.subtle)
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.dimText)
                    .lineLimit(1)
            }

            Spacer()

            // Waveform
            waveform

            // Duration
            Text(duration)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(AppTheme.accent.opacity(0.3))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private var waveform: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { i in
                let heights: [CGFloat] = [0.3, 0.5, 0.7, 0.9, 0.6, 0.8, 0.4, 0.7, 0.5, 0.9, 0.6, 0.3]
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.25))
                    .frame(width: 2, height: 16 * heights[i])
            }
        }
    }

    // MARK: - Stationery & Archives

    private var stationerySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Stationery & Archives")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("4 FILES")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.subtle))
            }

            HStack(spacing: 12) {
                fileCard(
                    name: "OctoberManifesto.pdf",
                    size: "2.4 MB",
                    updated: "Updated 2 days ago",
                    icon: "doc.text.fill",
                    color: .red.opacity(0.6)
                )

                fileCard(
                    name: "Midnight_Sketch_04.procreate",
                    size: "8.1 MB",
                    updated: "Updated 1 week ago",
                    icon: "paintbrush.fill",
                    color: AppTheme.accent.opacity(0.6)
                )

                fileCard(
                    name: "System_Themes.json",
                    size: "12 KB",
                    updated: "Updated 3 weeks ago",
                    icon: "doc.badge.gearshape.fill",
                    color: .cyan.opacity(0.6)
                )
            }
        }
    }

    private func fileCard(name: String, size: String, updated: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(height: 40)

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(size) · \(updated)")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.dimText)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        MediaGalleryView()
    }
}
