import SwiftUI
import SwiftData
import LocalAuthentication
#if canImport(UIKit)
import UIKit
#endif

@main
struct UllamApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let dataController = DataController.shared
    @State private var diaryManager: DiaryManager
    @State private var showPincodeOverlay: Bool = false
    @State private var hasCompletedOnboarding: Bool
    @State private var isAppLocked: Bool
    @State private var isAuthenticating: Bool = false

    private var biometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: "biometricEnabled")
    }

    init() {
        let manager = DiaryManager(modelContext: DataController.shared.container.mainContext)
        _diaryManager = State(initialValue: manager)

        // Check if onboarding is completed
        let udCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasExistingDiaries = !DataController.shared.fetchAllDiaries().isEmpty
        let completed = udCompleted || hasExistingDiaries
        if completed && !udCompleted {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        _hasCompletedOnboarding = State(initialValue: completed)

        // Start locked if biometric is enabled
        let bioEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        _isAppLocked = State(initialValue: bioEnabled)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    RootView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
                        .onAppear {
                            DataController.shared.createDefaultDiaryIfNeeded()
                            if !diaryManager.isUnlocked {
                                _ = diaryManager.openDefaultDiaryIfUnprotected()
                            }
                            AutoDestructService.shared.cleanupExpiredPages(
                                context: dataController.container.mainContext
                            )
                            // Trigger Face ID on first appear
                            if isAppLocked && !isAuthenticating {
                                authenticateWithBiometrics()
                            }
                        }
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .onChange(of: hasCompletedOnboarding) { _, completed in
                            if completed {
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                                let settings = dataController.getOrCreateSettings()
                                settings.hasCompletedOnboarding = true
                                try? dataController.container.mainContext.save()
                                DataController.shared.createDefaultDiaryIfNeeded()
                                _ = diaryManager.openDefaultDiaryIfUnprotected()
                            }
                        }
                }

                // Lock screen overlay
                if isAppLocked && hasCompletedOnboarding {
                    AppLockOverlay(
                        isAuthenticating: isAuthenticating,
                        onUnlock: { authenticateWithBiometrics() }
                    )
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAppLocked)
        }
        .modelContainer(dataController.container)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if diaryManager.currentDiary?.isProtected == true {
                diaryManager.lockCurrentDiary()
            }
            // Re-lock app when going to background
            if biometricEnabled {
                isAppLocked = true
            }
        case .inactive:
            break
        case .active:
            // Auto-trigger Face ID when returning to foreground
            if isAppLocked && biometricEnabled && !isAuthenticating {
                authenticateWithBiometrics()
            }
        @unknown default:
            break
        }
    }

    private func authenticateWithBiometrics() {
        guard biometricEnabled, isAppLocked else { return }
        isAuthenticating = true

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics unavailable — fall through to unlocked
            isAppLocked = false
            isAuthenticating = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock Ullam to access your diary"
        ) { success, _ in
            Task { @MainActor in
                isAuthenticating = false
                if success {
                    withAnimation(.easeOut(duration: 0.35)) {
                        isAppLocked = false
                    }
                }
            }
        }
    }
}

// MARK: - App Lock Overlay

private struct AppLockOverlay: View {
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Blurred background that hides all content
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Extra tinted layer for privacy
            AppTheme.bg.opacity(0.85)
                .ignoresSafeArea()

            // Lock UI
            VStack(spacing: 20) {
                Spacer()

                // Lock icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

                Text("Ullam")
                    .font(.custom("NewYork-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(AppTheme.primaryText)
                    .opacity(appeared ? 1 : 0)

                Text("Tap to unlock with Face ID")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.mutedText)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                // Unlock button
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18))
                        Text("Unlock")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(AppTheme.accent)
                    )
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(appeared ? 1 : 0)
                .disabled(isAuthenticating)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

struct RootView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    #if os(iOS)
    @State private var showPanicLockFlash: Bool = false
    #endif

    var body: some View {
        ZStack {
            if diaryManager.isUnlocked {
                MainTabView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
            } else {
                PincodeEntryView(diaryManager: diaryManager)
            }

            #if os(iOS)
            // Panic lock flash overlay
            if showPanicLockFlash {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.indigo.opacity(0.7))
                            Text("Locked")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.sage)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.3), value: diaryManager.isUnlocked)
        #if os(iOS)
        .modifier(ShakeDetectorModifier {
            triggerPanicLock()
        })
        #endif
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

    #if os(iOS)
    private func triggerPanicLock() {
        guard diaryManager.currentDiary?.isProtected == true else { return }

        PanicLockService.shared.performPanicLock(diaryManager: diaryManager)

        withAnimation(.easeIn(duration: 0.15)) {
            showPanicLockFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPanicLockFlash = false
            }
        }
    }
    #endif
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
                    AppTheme.bg,
                    AppTheme.bg,
                    AppTheme.sidebarBg,
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
                    .fill(AppTheme.subtle)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch Diary")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Choose your sanctuary")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.dimText)
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
                            .foregroundStyle(AppTheme.dimText)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.subtle)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.subtle, lineWidth: 1)
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
                                    .fill(AppTheme.subtle)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppTheme.subtle, lineWidth: 1)
                                    )
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.dimText)
                            }

                            Text("Create New Diary")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.dimText)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(SwitcherButtonStyle())

                    // Divider
                    Rectangle()
                        .fill(AppTheme.subtle)
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
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text("Enter pincode to reveal")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.dimText)
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
                    .foregroundStyle(AppTheme.dimText)
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
                        .foregroundStyle(AppTheme.dimText)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.subtle)
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
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.bottom, 4)
            } else {
                Text("Enter Pincode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.bottom, 4)
            }

            Text("4–6 digits")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.dimText)
                .padding(.bottom, 24)

            // Pincode dots
            HStack(spacing: 14) {
                ForEach(0..<maxDigits, id: \.self) { index in
                    let isFilled = index < enteredPincode.count
                    Circle()
                        .fill(isFilled ? AppTheme.accent : AppTheme.mutedText.opacity(0.15))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(isFilled ? AppTheme.accent.opacity(0.4) : AppTheme.subtle, lineWidth: 1)
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
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(
                                canSubmitPincode ?
                                LinearGradient(
                                    colors: [AppTheme.accent, Color(hex: 0xC49340)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [AppTheme.subtle, AppTheme.subtle],
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
                        .fill(isCurrent ? AppTheme.accent.opacity(0.12) : AppTheme.subtle)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isCurrent ? AppTheme.accent.opacity(0.2) : AppTheme.subtle, lineWidth: 1)
                        )

                    Image(systemName: diary.isProtected ? "lock.fill" : "text.book.closed.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            diary.isProtected ? AppTheme.indigo.opacity(0.6) :
                            isCurrent ? AppTheme.accent : AppTheme.dimText
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(diary.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("\((diary.pages?.count ?? 0)) entries")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.dimText)
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
                        .foregroundStyle(AppTheme.dimText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrent ? AppTheme.subtle : AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isCurrent ? AppTheme.accent.opacity(0.12) : AppTheme.subtle, lineWidth: 1)
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

// MARK: - Shake Gesture Detection (iOS)

#if os(iOS)

/// A ViewModifier that detects device shake gestures via a hidden UIKit responder.
struct ShakeDetectorModifier: ViewModifier {
    let onShake: () -> Void

    func body(content: Content) -> some View {
        content
            .background(ShakeDetectorRepresentable(onShake: onShake))
    }
}

private struct ShakeDetectorRepresentable: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        let vc = ShakeDetectorViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

final class ShakeDetectorViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
        super.motionEnded(motion, with: event)
    }
}

#endif // os(iOS)
