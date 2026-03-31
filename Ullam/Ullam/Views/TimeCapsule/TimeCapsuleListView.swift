#if os(iOS)
import SwiftUI
import SwiftData

struct TimeCapsuleListView: View {
    @Bindable var diaryManager: DiaryManager

    @State private var capsules: [TimeCapsule] = []
    @State private var showCreateSheet = false
    @State private var openedCapsule: TimeCapsule?
    @State private var revealedMessage: String?
    @State private var isRevealing = false
    @State private var appeared = false
    @State private var breathe = false

    private let service = TimeCapsuleService.shared

    private var readyToOpen: [TimeCapsule] {
        capsules.filter { $0.isUnlocked && !$0.isOpened }
    }

    private var waiting: [TimeCapsule] {
        capsules.filter { !$0.isUnlocked }
    }

    private var opened: [TimeCapsule] {
        capsules.filter { $0.isOpened }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    if capsules.isEmpty {
                        emptyState
                    } else {
                        // Ready to open
                        if !readyToOpen.isEmpty {
                            sectionHeader("Ready to Open", icon: "sparkles", color: AppTheme.moodHappy)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                            ForEach(readyToOpen, id: \.id) { capsule in
                                unlockedCard(capsule)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                            }
                        }

                        // Waiting
                        if !waiting.isEmpty {
                            sectionHeader("Waiting", icon: "hourglass", color: AppTheme.accent)
                                .padding(.horizontal, 20)
                                .padding(.top, readyToOpen.isEmpty ? 0 : 16)
                                .padding(.bottom, 12)

                            ForEach(waiting, id: \.id) { capsule in
                                lockedCard(capsule)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            }
                        }

                        // Previously opened
                        if !opened.isEmpty {
                            sectionHeader("Opened", icon: "envelope.open", color: AppTheme.dimText)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 12)

                            ForEach(opened, id: \.id) { capsule in
                                openedCard(capsule)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            }
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    createFAB
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                }
            }

            // Reveal overlay
            if isRevealing, let capsule = openedCapsule {
                revealOverlay(capsule)
                    .transition(.opacity)
            }
        }
        .onAppear {
            loadCapsules()
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { breathe = true }
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: loadCapsules) {
            CreateTimeCapsuleView(diaryManager: diaryManager)
                .presentationBackground(AppTheme.bg)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.bg, AppTheme.bg, AppTheme.sidebarBg],
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
                colors: [AppTheme.moodHappy.opacity(0.03), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Capsules")
                .font(.custom("NewYork-Bold", size: 28, relativeTo: .largeTitle))
                .foregroundStyle(AppTheme.primaryText)

            Text("Messages to your future self")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
        .animation(.easeOut(duration: 0.4), value: appeared)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(color.opacity(0.7))

            Rectangle()
                .fill(color.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - Unlocked Card (glowing, ready to open)

    private func unlockedCard(_ capsule: TimeCapsule) -> some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                openedCapsule = capsule
                isRevealing = true
            }
            service.openCapsule(capsule)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppTheme.moodHappy.opacity(breathe ? 0.2 : 0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "gift.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.moodHappy)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready to open!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.moodHappy)
                        Text("Created \(formattedDate(capsule.createdAt))")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.dimText)
                    }

                    Spacer()

                    Text("Open")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.moodHappy, Color(hex: 0xF59E0B)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [AppTheme.moodHappy.opacity(0.4), AppTheme.moodHappy.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: AppTheme.moodHappy.opacity(breathe ? 0.2 : 0.1), radius: breathe ? 16 : 10, y: 4)
        }
        .buttonStyle(CapsuleCardButtonStyle())
    }

    // MARK: - Locked Card (with countdown)

    private func lockedCard(_ capsule: TimeCapsule) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(breathe ? 0.12 : 0.06))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(AppTheme.accent.opacity(0.15), lineWidth: 1))
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent.opacity(0.6))
                    .scaleEffect(breathe ? 1.05 : 0.95)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(countdownText(capsule.unlockDate))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("Sealed \(formattedDate(capsule.createdAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.accent.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )
        )
    }

    // MARK: - Opened Card

    private func openedCard(_ capsule: TimeCapsule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)

                Text("Opened \(formattedDate(capsule.openedDate ?? capsule.unlockDate))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)

                Spacer()
            }

            Text(capsule.message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.dimText)
                .lineLimit(3)
                .lineSpacing(4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.subtle, lineWidth: 1)
                )
        )
    }

    // MARK: - Reveal Overlay

    private func revealOverlay(_ capsule: TimeCapsule) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isRevealing = false
                        openedCapsule = nil
                    }
                    loadCapsules()
                }

            VStack(spacing: 24) {
                Spacer()

                // Capsule icon
                ZStack {
                    Circle()
                        .fill(AppTheme.moodHappy.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(AppTheme.moodHappy.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.moodHappy)
                }

                Text("A message from the past")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.dimText)
                    .tracking(1)

                // Message
                Text(capsule.message)
                    .font(.custom("NewYork-Regular", size: 20, relativeTo: .title3))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 32)

                // Date info
                Text("Written \(formattedDate(capsule.createdAt))")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)

                Spacer()

                // Dismiss
                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isRevealing = false
                        openedCapsule = nil
                    }
                    loadCapsules()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.sage)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppTheme.subtle)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(breathe ? 0.1 : 0.04))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(AppTheme.accent.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "shippingbox")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.accent.opacity(0.4))
                    .scaleEffect(breathe ? 1.05 : 1.0)
            }

            VStack(spacing: 6) {
                Text("No time capsules yet")
                    .font(.custom("NewYork-Bold", size: 20, relativeTo: .title3))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("Write a message to your future self")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.dimText)
            }

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Create First Capsule")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
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
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
    }

    // MARK: - FAB

    private var createFAB: some View {
        Button {
            showCreateSheet = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(breathe ? 0.3 : 0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: breathe ? 45 : 35
                        )
                    )
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, Color(hex: 0xC49340)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.accent.opacity(breathe ? 0.45 : 0.25), radius: breathe ? 20 : 12, y: 6)
                    .overlay(Circle().stroke(AppTheme.subtle, lineWidth: 1))

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .scaleEffect(breathe ? 1.04 : 1.0)
        }
        .buttonStyle(CapsuleCardButtonStyle())
        .opacity(capsules.isEmpty ? 0 : (appeared ? 1 : 0))
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: appeared)
    }

    // MARK: - Helpers

    private func loadCapsules() {
        guard let diary = diaryManager.currentDiary else { return }
        let context = DataController.shared.container.mainContext
        capsules = service.getAllCapsules(diary: diary, context: context)
    }

    private func countdownText(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: now, to: date)
        let days = components.day ?? 0
        let hours = components.hour ?? 0

        if days > 30 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return "Opens \(formatter.string(from: date))"
        } else if days > 0 {
            return "Opens in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "Opens in \(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "Opens soon"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Button Style

private struct CapsuleCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#endif // os(iOS)
