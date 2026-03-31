import SwiftUI
import SwiftData

// MARK: - Main Onboarding Container

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentPage = 0
    @State private var selectedStorage: StoragePreference = .local

    // Shared dark theme (using AppTheme palette)
    static let bgColor = AppTheme.bg
    static let accentPurple = AppTheme.accent
    static let subtitleColor = AppTheme.mutedText

    private let totalPages = 4

    var body: some View {
        ZStack {
            OnboardingView.bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.top, 8)

                // Page content
                TabView(selection: $currentPage) {
                    WelcomePageView(onBegin: { goNext() })
                        .tag(0)

                    PrivacyPageView()
                        .tag(1)

                    EmotionsPageView()
                        .tag(2)

                    SetupPageView(
                        selectedStorage: $selectedStorage,
                        onCreateDiary: { completeOnboarding() }
                    )
                    .tag(3)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut(duration: 0.4), value: currentPage)

                // Bottom controls (not on welcome or setup)
                if currentPage > 0 && currentPage < 3 {
                    bottomControls
                }

                // Footer
                footer
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(AppThemeHelper.preferredScheme)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if currentPage == 3 {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            } else {
                // Decorative dots (macOS window chrome area)
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                }
                .opacity(0) // Hidden but takes space
            }

            Spacer()

            if currentPage > 0 && currentPage < 3 {
                Text("Midnight Paper")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            } else if currentPage == 0 {
                Text("ULLAM PRIVATE SANCTUARY")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.2))
            }

            Spacer()

            if currentPage > 0 && currentPage < 3 {
                Button {
                    completeOnboarding()
                } label: {
                    Text("SKIP")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 40, height: 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? OnboardingView.accentPurple : .white.opacity(0.15))
                        .frame(width: index == currentPage ? 20 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }

            // Back / Next buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    goNext()
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(OnboardingView.accentPurple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            if currentPage > 0 && currentPage < 3 {
                HStack(spacing: 12) {
                    Button("Privacy Policy") {}
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.15))
                    Button("Terms of Service") {}
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .buttonStyle(.plain)
            }

            Text("\u{00A9} 2024 Midnight Paper. Your sanctuary is private.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.15))
        }
    }

    // MARK: - Actions

    private func goNext() {
        guard currentPage < totalPages - 1 else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            currentPage += 1
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Page 1: Welcome

struct WelcomePageView: View {
    var onBegin: () -> Void

    @State private var iconAppeared = false
    @State private var textAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Sparkle icon badge
            ZStack {
                // Outer glow
                Circle()
                    .fill(OnboardingView.accentPurple.opacity(0.08))
                    .frame(width: 140, height: 140)

                // Badge background
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.18, blue: 0.30),
                                Color(red: 0.12, green: 0.11, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )

                // Icon
                VStack(spacing: 4) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(OnboardingView.accentPurple.opacity(0.9))

                    Text("PRIVATE SPACE")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .scaleEffect(iconAppeared ? 1 : 0.6)
            .opacity(iconAppeared ? 1 : 0)
            .padding(.bottom, 32)

            // Title
            Text("Welcome to Ullam")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .opacity(textAppeared ? 1 : 0)
                .offset(y: textAppeared ? 0 : 16)
                .padding(.bottom, 12)

            // Subtitle
            Text("Your private space for thoughts, feelings, and memories.\nBuilt with end-to-end encryption for your peace of mind.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingView.subtitleColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .opacity(textAppeared ? 1 : 0)
                .offset(y: textAppeared ? 0 : 12)
                .padding(.bottom, 40)

            // Begin button
            Button(action: onBegin) {
                Text("Begin Your Journey")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(OnboardingView.accentPurple.opacity(0.7))
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .opacity(textAppeared ? 1 : 0)
            .offset(y: textAppeared ? 0 : 10)

            Spacer()

            // Log in link
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(.white.opacity(0.25))
                Button("Log in") {}
                    .foregroundStyle(.white.opacity(0.5))
                    .fontWeight(.semibold)
                    .buttonStyle(.plain)
            }
            .font(.system(size: 13))
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                iconAppeared = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textAppeared = true
            }
        }
    }
}

// MARK: - Page 2: Privacy

struct PrivacyPageView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Floating card illustration
            ZStack {
                // Shadow cards behind
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 220, height: 260)
                    .rotationEffect(.degrees(-4))
                    .offset(x: -10, y: 10)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 220, height: 260)
                    .rotationEffect(.degrees(2))
                    .offset(x: 8, y: 6)

                // Main card
                VStack(spacing: 16) {
                    // Lock badge
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 52, height: 52)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(OnboardingView.accentPurple.opacity(0.8))
                    }

                    // Pincode dots
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Fake content lines
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 160, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 120, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 140, height: 6)
                    }
                    .padding(.top, 8)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.14, green: 0.14, blue: 0.17),
                                    Color(red: 0.10, green: 0.10, blue: 0.13)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.06), lineWidth: 1)
                        )
                )
            }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 40)

            // Title
            Text("Truly private")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .padding(.bottom, 12)

            // Description
            Text("Create separate diaries with their own pincodes.\nHidden diaries never appear unless you unlock them.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingView.subtitleColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
        }
    }
}

// MARK: - Page 3: Emotions

struct EmotionsPageView: View {
    @State private var appeared = false

    // Mood grid colors
    private let moodColors: [Color] = [
        Color(red: 0.25, green: 0.28, blue: 0.40), // blue-ish
        Color(red: 0.18, green: 0.20, blue: 0.28), // dark neutral
        Color(red: 0.35, green: 0.38, blue: 0.55), // medium blue
        Color(red: 0.15, green: 0.16, blue: 0.22), // very dark
        Color(red: 0.30, green: 0.32, blue: 0.48), // purple-blue
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Track your emotional\njourney")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Text("Add emojis to entries and view your year at a glance through an\nemotional mosaic.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(OnboardingView.subtitleColor)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)
                .opacity(appeared ? 1 : 0)

            Spacer()

            // Mood mosaic grid
            ZStack(alignment: .topTrailing) {
                moodGrid
                    .padding(.horizontal, 20)

                // Floating card
                floatingEntryCard
                    .offset(x: -16, y: -12)
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)

            // Legend
            HStack(spacing: 20) {
                legendItem(color: moodColors[3], label: "LOW TIDE")
                legendItem(color: moodColors[1], label: "NEUTRAL")
                legendItem(color: moodColors[2], label: "HIGH TIDE")
            }
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // Decorative sparkle
            HStack {
                Spacer()
                Image(systemName: "sparkle")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.06))
                    .rotationEffect(.degrees(15))
                    .padding(.trailing, 40)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
        }
    }

    private var moodGrid: some View {
        VStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<14, id: \.self) { col in
                        let pseudoRandom = (row * 7 + col * 3 + row * col) % moodColors.count
                        RoundedRectangle(cornerRadius: 3)
                            .fill(moodColors[pseudoRandom])
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private var floatingEntryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(OnboardingView.accentPurple)

            Text("Feeling Radiant")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)

            Text("Finalized the final chapter of my book. The moonlight feels particularly soft tonight...")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.black.opacity(0.6))
                .lineLimit(3)
        }
        .padding(12)
        .frame(width: 170)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.96, green: 0.94, blue: 0.88))
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

// MARK: - Page 4: Setup

struct SetupPageView: View {
    @Binding var selectedStorage: StoragePreference
    var onCreateDiary: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            Text("Set up your sanctuary")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 10)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Text("Choose where your memories live. Your sanctuary is\nprivate by default.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(OnboardingView.subtitleColor)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)

            // Storage option cards
            AdaptiveStack(spacing: 16) {
                storageCard(
                    icon: "iphone",
                    title: "Local Only",
                    subtitle: "MAXIMUM PRIVACY",
                    description: "Data stays exclusively on this device. No cloud, no external servers. Pure offline tranquility.",
                    preference: .local
                )

                storageCard(
                    icon: "icloud",
                    title: "iCloud Sync",
                    subtitle: "ACCESS EVERYWHERE",
                    description: "Seamlessly sync across your iPhone, iPad, and Mac. Protected by end-to-end encryption.",
                    preference: .iCloud
                )
            }
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // Create diary button
            Button(action: onCreateDiary) {
                Text("Create First Diary")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(OnboardingView.accentPurple)
                    )
            }
            .buttonStyle(.plain)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 32)

            // Security footer
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                Text("ENCRYPTED WITH 256-BIT SECURITY")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
            }
            .foregroundStyle(.white.opacity(0.15))
            .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
        }
    }

    private func storageCard(icon: String, title: String, subtitle: String, description: String, preference: StoragePreference) -> some View {
        let isSelected = selectedStorage == preference

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedStorage = preference
            }
        } label: {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(OnboardingView.accentPurple.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(OnboardingView.accentPurple.opacity(isSelected ? 1 : 0.6))
                }

                // Title
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(OnboardingView.accentPurple.opacity(0.7))

                // Description
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? OnboardingView.accentPurple.opacity(0.4) : .white.opacity(0.06),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Adaptive Stack (HStack on macOS, VStack on iOS)

struct AdaptiveStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if os(iOS)
        VStack(spacing: spacing) { content() }
        #else
        HStack(spacing: spacing) { content() }
        #endif
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
