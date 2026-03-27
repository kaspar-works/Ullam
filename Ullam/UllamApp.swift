import SwiftUI
import SwiftData

@main
struct UllamApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let dataController = DataController.shared
    @State private var diaryManager: DiaryManager
    @State private var showPincodeOverlay: Bool = false
    @State private var hasCompletedOnboarding: Bool

    init() {
        let manager = DiaryManager(modelContext: DataController.shared.container.mainContext)
        _diaryManager = State(initialValue: manager)

        // Check if onboarding is completed
        // Use UserDefaults as primary flag, but also check if diaries exist (handles schema resets)
        let udCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasExistingDiaries = !DataController.shared.fetchAllDiaries().isEmpty
        let completed = udCompleted || hasExistingDiaries
        if completed && !udCompleted {
            // Backfill UserDefaults so we don't check DB every launch
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        _hasCompletedOnboarding = State(initialValue: completed)
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
                    .onAppear {
                        // Create default diary if needed (only after onboarding)
                        DataController.shared.createDefaultDiaryIfNeeded()

                        // Auto-open default diary if not protected
                        if !diaryManager.isUnlocked {
                            _ = diaryManager.openDefaultDiaryIfUnprotected()
                        }

                        // Seed sample data on first launch
                        SampleDataGenerator.seedIfNeeded(diaryManager: diaryManager)
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .onChange(of: hasCompletedOnboarding) { _, completed in
                        if completed {
                            // Save to UserDefaults (survives DB resets)
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                            // Also save in DB settings
                            let settings = dataController.getOrCreateSettings()
                            settings.hasCompletedOnboarding = true
                            try? dataController.container.mainContext.save()

                            // Create default diary
                            DataController.shared.createDefaultDiaryIfNeeded()

                            // Open default diary
                            _ = diaryManager.openDefaultDiaryIfUnprotected()
                        }
                    }
            }
        }
        .modelContainer(dataController.container)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock diary when app goes to background if it's protected
            if diaryManager.currentDiary?.isProtected == true {
                diaryManager.lockCurrentDiary()
            }
        case .inactive:
            break
        case .active:
            break
        @unknown default:
            break
        }
    }
}

struct RootView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    var body: some View {
        ZStack {
            if diaryManager.isUnlocked {
                MainTabView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
            } else {
                PincodeEntryView(diaryManager: diaryManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: diaryManager.isUnlocked)
        #if os(iOS)
        .sheet(isPresented: $showPincodeOverlay) {
            DirarySwitcherView(diaryManager: diaryManager, isPresented: $showPincodeOverlay)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
                .presentationCornerRadius(28)
        }
        #else
        .sheet(isPresented: $showPincodeOverlay) {
            DirarySwitcherView(diaryManager: diaryManager, isPresented: $showPincodeOverlay)
                .frame(minWidth: 400, minHeight: 500)
        }
        #endif
    }
}

// MARK: - Diary Switcher (Premium Bottom Sheet)

struct DirarySwitcherView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var isPresented: Bool

    @State private var visibleDiaries: [Diary] = []
    @State private var selectedDiary: Diary?
    @State private var enteredPincode: String = ""
    @State private var isUnlocking: Bool = false
    @State private var shake: Bool = false
    @State private var showPincodeEntry: Bool = false
    @State private var showCreateDiary: Bool = false

    let minDigits = 4
    let maxDigits = 6

    var canSubmitPincode: Bool {
        enteredPincode.count >= minDigits && enteredPincode.count <= maxDigits
    }

    var body: some View {
        ZStack {
            // Background
            switcherBackground.ignoresSafeArea()

            if showPincodeEntry {
                // Step 2: Focused pincode unlock screen
                pincodeUnlockView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            } else {
                // Step 1: Diary selection
                diarySelectionView
                    .transition(.opacity)
            }

            // Loading overlay
            if isUnlocking {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showPincodeEntry)
        .disabled(isUnlocking)
        .onAppear {
            visibleDiaries = diaryManager.getVisibleDiaries()
        }
    }

    // MARK: - Background

    private var switcherBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0E1526),
                    Color(hex: 0x12152E),
                    Color(hex: 0x180F35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [AppTheme.accent.opacity(0.06), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    // MARK: - Step 1: Diary Selection

    private var diarySelectionView: some View {
        VStack(spacing: 0) {
            // Handle + header
            VStack(spacing: 16) {
                // Drag handle
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch Diary")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Choose your sanctuary")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    Spacer()

                    Button {
                        isPresented = false
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.06))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .buttonStyle(SwitcherButtonStyle())
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)

            // Diary list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(visibleDiaries) { diary in
                        SwitcherDiaryRow(
                            diary: diary,
                            isCurrent: diary.id == diaryManager.currentDiary?.id,
                            onTap: { selectDiary(diary) }
                        )
                    }

                    // Spacer
                    Spacer().frame(height: 8)

                    // Create new diary
                    Button {
                        showCreateDiary = true
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white.opacity(0.04))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.white.opacity(0.06), lineWidth: 1)
                                    )
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.3))
                            }

                            Text("Create New Diary")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(SwitcherButtonStyle())

                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.04))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    // Unlock hidden diary
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedDiary = nil
                            showPincodeEntry = true
                            enteredPincode = ""
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.indigo.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppTheme.indigo.opacity(0.15), lineWidth: 1)
                                    )
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.indigo.opacity(0.6))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unlock Hidden Diary")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("Enter pincode to reveal")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.25))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.indigo.opacity(0.4))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.indigo.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.indigo.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(SwitcherButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showCreateDiary) {
            NavigationStack {
                DiaryCreationView(diaryManager: diaryManager)
            }
            .onDisappear {
                visibleDiaries = diaryManager.getVisibleDiaries()
            }
        }
    }

    // MARK: - Step 2: Pincode Unlock (focused)

    private var pincodeUnlockView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showPincodeEntry = false
                        enteredPincode = ""
                        selectedDiary = nil
                    }
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(SwitcherButtonStyle())

                Spacer()

                Button {
                    isPresented = false
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(SwitcherButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Lock icon
            ZStack {
                Circle()
                    .fill(AppTheme.indigo.opacity(0.08))
                    .frame(width: 64, height: 64)

                Circle()
                    .stroke(AppTheme.indigo.opacity(0.15), lineWidth: 1)
                    .frame(width: 64, height: 64)

                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.indigo.opacity(0.6))
            }
            .shadow(color: AppTheme.indigo.opacity(0.1), radius: 16)
            .padding(.bottom, 16)

            // Title
            if let diary = selectedDiary {
                Text("Unlock \(diary.name)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
            } else {
                Text("Enter Pincode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
            }

            Text("4–6 digits")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.bottom, 24)

            // Pincode dots
            HStack(spacing: 14) {
                ForEach(0..<maxDigits, id: \.self) { index in
                    let isFilled = index < enteredPincode.count
                    Circle()
                        .fill(isFilled ? AppTheme.accent : .white.opacity(0.1))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(isFilled ? AppTheme.accent.opacity(0.4) : .white.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: isFilled ? AppTheme.accent.opacity(0.3) : .clear, radius: 6)
                        .scaleEffect(isFilled ? 1.1 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: enteredPincode.count)
                }
            }
            .modifier(ShakeEffect(shake: shake))
            .padding(.bottom, 32)

            // Numpad (compact)
            NumpadView(
                enteredValue: $enteredPincode,
                maxDigits: maxDigits,
                onComplete: { attemptUnlock() }
            )
            .padding(.horizontal, 20)

            Spacer()

            // Unlock button
            Button {
                attemptUnlock()
            } label: {
                Text("Unlock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(
                                canSubmitPincode ?
                                LinearGradient(
                                    colors: [AppTheme.accent, Color(hex: 0x7C3AED)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [.white.opacity(0.06), .white.opacity(0.04)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: canSubmitPincode ? AppTheme.accent.opacity(0.25) : .clear, radius: 12, y: 4)
            }
            .buttonStyle(SwitcherButtonStyle())
            .disabled(!canSubmitPincode || isUnlocking)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.2), value: canSubmitPincode)
        }
    }

    // MARK: - Actions

    private func selectDiary(_ diary: Diary) {
        if diary.isProtected {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedDiary = diary
                showPincodeEntry = true
                enteredPincode = ""
            }
        } else {
            diaryManager.openDiary(diary)
            isPresented = false
        }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func attemptUnlock() {
        guard canSubmitPincode else { return }
        isUnlocking = true

        Task {
            var success = false
            if let diary = selectedDiary {
                success = await diaryManager.unlockSpecificDiary(diary, with: enteredPincode)
            } else {
                success = await diaryManager.unlockDiary(with: enteredPincode)
            }

            isUnlocking = false
            if success {
                isPresented = false
            } else {
                showErrorFeedback()
            }
            enteredPincode = ""
        }
    }

    private func showErrorFeedback() {
        withAnimation(.default) { shake = true }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
        }
    }
}

// MARK: - Diary Row (for switcher)

struct SwitcherDiaryRow: View {
    let diary: Diary
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isCurrent ? AppTheme.accent.opacity(0.12) : .white.opacity(0.04))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isCurrent ? AppTheme.accent.opacity(0.2) : .white.opacity(0.06), lineWidth: 1)
                        )

                    Image(systemName: diary.isProtected ? "lock.fill" : "text.book.closed.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            diary.isProtected ? AppTheme.indigo.opacity(0.6) :
                            isCurrent ? AppTheme.accent : .white.opacity(0.35)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(diary.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("\((diary.pages?.count ?? 0)) entries")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }

                Spacer()

                if isCurrent {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: 0x34D399))
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0x34D399).opacity(0.08))
                    )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.15))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrent ? .white.opacity(0.04) : .white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isCurrent ? AppTheme.accent.opacity(0.12) : .white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SwitcherButtonStyle())
    }
}

// Keep old name for compatibility
typealias DiaryRowButton = SwitcherDiaryRow

private struct SwitcherButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
