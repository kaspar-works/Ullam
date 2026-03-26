#if os(iOS)
import SwiftUI

struct MediaMobileView: View {
    @State private var selectedFilter: String = "Photos"

    private let filters = ["Photos", "Videos", "Audio"]
    private let subFilters = ["All Diaries", "Date", "Emotion"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Media Library")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Text("A sanctuary for your captured moments.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.dimText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Primary filter tabs
                HStack(spacing: 0) {
                    ForEach(filters, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter)
                                .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .regular))
                                .foregroundStyle(selectedFilter == filter ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    selectedFilter == filter ?
                                    Capsule().fill(AppTheme.accent.opacity(0.25)) :
                                    Capsule().fill(Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // Sub filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(subFilters, id: \.self) { filter in
                            Text(filter)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)

                // Photo grid
                photoGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                // Voice Diaries
                voiceDiaries
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .background(AppTheme.bg)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        let gradients: [(Color, Color)] = [
            (Color(red: 0.20, green: 0.18, blue: 0.35), Color(red: 0.08, green: 0.08, blue: 0.18)),
            (Color(red: 0.50, green: 0.35, blue: 0.20), Color(red: 0.25, green: 0.15, blue: 0.08)),
            (Color(red: 0.15, green: 0.30, blue: 0.35), Color(red: 0.05, green: 0.12, blue: 0.18)),
            (Color(red: 0.35, green: 0.25, blue: 0.18), Color(red: 0.15, green: 0.10, blue: 0.06)),
        ]

        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: [gradients[i].0, gradients[i].1], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(height: i % 2 == 0 ? 180 : 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.05), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Voice Diaries

    private var voiceDiaries: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.accent)
                Text("Voice Diaries")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            voiceRow(title: "Midnight Thoughts", date: "RECORDED OCT 23 · 3:44", duration: "")
            voiceRow(title: "Rainy Morning Session", date: "RECORDED OCT · 04 · 1:10", duration: "")
        }
    }

    private func voiceRow(title: String, date: String, duration: String) -> some View {
        HStack(spacing: 12) {
            Button {} label: {
                ZStack {
                    Circle().fill(AppTheme.subtle).frame(width: 36, height: 36)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(date)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()

            // Waveform
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    let h: [CGFloat] = [0.3, 0.6, 0.8, 0.5, 0.9, 0.4, 0.7, 0.3]
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.2))
                        .frame(width: 2, height: 14 * h[i])
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(AppTheme.subtle)
        )
    }
}
#endif // os(iOS)
