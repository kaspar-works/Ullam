#if os(iOS)
import SwiftUI
import UIKit

struct WeeklyReflectionView: View {
    @Bindable var diaryManager: DiaryManager
    @Environment(\.dismiss) private var dismiss

    @State private var reflection: WeeklyReflection?
    @State private var isLoading = true
    @State private var appeared = false
    @State private var statsAppeared = false
    @State private var moodArcAppeared = false
    @State private var themesAppeared = false
    @State private var textAppeared = false
    @State private var suggestionAppeared = false
    @State private var glowPulse = false
    @State private var showShareSheet = false

    private let service = WeeklyReflectionService()

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let reflection = reflection {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection(reflection)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 24)

                        statsRow(reflection)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        moodArcSection(reflection)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        themesSection(reflection)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        reflectionTextSection(reflection)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        suggestionCard(reflection)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)

                        actionButtons
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)
                    }
                }
            } else {
                emptyView
            }
        }
        .task {
            reflection = await service.generateWeeklyReflection(diaryManager: diaryManager)
            isLoading = false
            service.markAsSeen()

            // Staggered entrance animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                statsAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                moodArcAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.55)) {
                themesAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.7)) {
                textAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.85)) {
                suggestionAppeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0)) {
                glowPulse = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let reflection = reflection {
                ShareSheet(text: shareText(for: reflection))
            }
        }
    }

    // MARK: - Background

    private var background: some View {
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
                colors: [AppTheme.accent.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 400
            )

            RadialGradient(
                colors: [AppTheme.gradientPink.opacity(0.05), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 350
            )
        }
    }

    // MARK: - Header

    private func headerSection(_ reflection: WeeklyReflection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.dimText)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .clipShape(Circle())
                }

                Spacer()

                Button {
                    showShareSheet = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.dimText)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .clipShape(Circle())
                }
            }

            Text("Your Week in Review")
                .font(.custom("NewYork-Bold", size: 30, relativeTo: .largeTitle))
                .foregroundStyle(AppTheme.primaryText)

            Text(dateRangeString(reflection))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -15)
    }

    // MARK: - Stats Row

    private func statsRow(_ reflection: WeeklyReflection) -> some View {
        HStack(spacing: 12) {
            statCard(
                icon: "doc.text.fill",
                value: "\(reflection.totalEntries)",
                label: "Entries",
                color: AppTheme.accent
            )

            statCard(
                icon: "textformat.abc",
                value: formattedWordCount(reflection.totalWords),
                label: "Words",
                color: AppTheme.gradientPink
            )

            statCard(
                icon: "flame.fill",
                value: streakValue(),
                label: "Streak",
                color: Color(hex: 0xFDBA74)
            )
        }
        .opacity(statsAppeared ? 1 : 0)
        .offset(y: statsAppeared ? 0 : 15)
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Mood Arc

    private func moodArcSection(_ reflection: WeeklyReflection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MOOD ARC")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.dimText)

            // Visual emoji journey
            if let mood = reflection.dominantMood {
                HStack(spacing: 0) {
                    let arcEmojis = moodArcEmojis(reflection)

                    ForEach(Array(arcEmojis.enumerated()), id: \.offset) { index, emoji in
                        if index > 0 {
                            // Connecting gradient line
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppTheme.gradientBlue.opacity(0.3),
                                            AppTheme.accent.opacity(0.3),
                                            AppTheme.gradientPink.opacity(0.3),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 2)
                                .scaleEffect(x: moodArcAppeared ? 1 : 0, anchor: .leading)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.8).delay(0.1 * Double(index)),
                                    value: moodArcAppeared
                                )
                        }

                        VStack(spacing: 4) {
                            Text(emoji)
                                .font(.system(size: 28))
                                .scaleEffect(moodArcAppeared ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.6).delay(0.08 * Double(index)),
                                    value: moodArcAppeared
                                )

                            Text(index == 0 ? "Start" : (index == arcEmojis.count - 1 ? "End" : "Mid"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppTheme.dimText)
                        }
                    }
                }
                .padding(.vertical, 8)

                Text(reflection.moodArc)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.mutedText)
                    .lineSpacing(4)
            } else {
                Text(reflection.moodArc)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.mutedText)
                    .lineSpacing(4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )
        )
        .opacity(moodArcAppeared ? 1 : 0)
        .offset(y: moodArcAppeared ? 0 : 15)
    }

    // MARK: - Themes

    private func themesSection(_ reflection: WeeklyReflection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP THEMES")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.dimText)

            FlowLayout(spacing: 8) {
                ForEach(Array(reflection.themes.enumerated()), id: \.offset) { index, theme in
                    Text(theme)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(themeColor(index).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(themeColor(index).opacity(0.2), lineWidth: 1)
                                )
                        )
                        .scaleEffect(themesAppeared ? 1 : 0.5)
                        .opacity(themesAppeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7).delay(0.06 * Double(index)),
                            value: themesAppeared
                        )
                }
            }
        }
        .opacity(themesAppeared ? 1 : 0)
        .offset(y: themesAppeared ? 0 : 15)
    }

    // MARK: - Reflection Text

    private func reflectionTextSection(_ reflection: WeeklyReflection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REFLECTION")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.dimText)

            Text(reflection.reflectionText)
                .font(.custom("NewYork-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(AppTheme.sage)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(textAppeared ? 1 : 0)
        .offset(y: textAppeared ? 0 : 15)
    }

    // MARK: - Suggestion Card

    private func suggestionCard(_ reflection: WeeklyReflection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("For Next Week")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Text(reflection.suggestion)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.sage)
                .lineSpacing(5)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.accent.opacity(glowPulse ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.25),
                                    AppTheme.gradientPink.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: AppTheme.accent.opacity(glowPulse ? 0.15 : 0.05), radius: 20, y: 8)
        .opacity(suggestionAppeared ? 1 : 0)
        .offset(y: suggestionAppeared ? 0 : 15)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color(hex: 0xC49340)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(ReflectionButtonStyle())

            Button {
                showShareSheet = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Share")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(AppTheme.subtle)
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.subtle, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ReflectionButtonStyle())
        }
        .opacity(suggestionAppeared ? 1 : 0)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppTheme.dimText)
            Text("Reflecting on your week...")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.accent.opacity(0.3))

            Text("Not enough entries this week")
                .font(.custom("NewYork-Bold", size: 20, relativeTo: .title3))
                .foregroundStyle(AppTheme.sage)

            Text("Write a few entries and come back for your reflection.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppTheme.accent))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func dateRangeString(_ reflection: WeeklyReflection) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: reflection.weekStartDate)) - \(f.string(from: reflection.weekEndDate))"
    }

    private func formattedWordCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    private func streakValue() -> String {
        // Calculate streak from diary manager
        var streak = 0
        let cal = Calendar.current
        var checkDate = Date()
        for _ in 0..<30 {
            let pages = diaryManager.getPages(for: checkDate)
            if pages.isEmpty { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return "\(streak)"
    }

    private func moodArcEmojis(_ reflection: WeeklyReflection) -> [String] {
        if let mood = reflection.dominantMood {
            // Use the dominant mood and sentimentally vary it
            let moodArc = reflection.moodArc.lowercased()
            if moodArc.contains("uplifted") || moodArc.contains("hopeful") {
                return ["🌅", mood.emoji, "✨"]
            } else if moodArc.contains("introspective") || moodArc.contains("contemplative") {
                return ["🌙", mood.emoji, "💭"]
            } else {
                return ["🌊", mood.emoji, "🌸"]
            }
        }
        return ["🌅", "🌊", "🌙"]
    }

    private func themeColor(_ index: Int) -> Color {
        let colors = [
            AppTheme.accent,
            AppTheme.gradientPink,
            AppTheme.gradientBlue,
            AppTheme.moodHappy,
            AppTheme.moodCalm,
            AppTheme.moodSad,
        ]
        return colors[index % colors.count]
    }

    private func shareText(for reflection: WeeklyReflection) -> String {
        var text = "My Week in Review\n"
        text += dateRangeString(reflection) + "\n\n"
        text += "\(reflection.totalEntries) entries | \(reflection.totalWords) words\n\n"
        if !reflection.themes.isEmpty {
            text += "Themes: " + reflection.themes.joined(separator: ", ") + "\n\n"
        }
        text += reflection.reflectionText + "\n\n"
        text += "-- Written with Ullam"
        return text
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxHeight = max(maxHeight, y + rowHeight)
        }

        return (CGSize(width: width, height: maxHeight), positions)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Button Style

private struct ReflectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#endif // os(iOS)
