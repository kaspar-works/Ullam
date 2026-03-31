import SwiftUI
import SwiftData
import LocalAuthentication

struct PincodeEntryView: View {
    @Bindable var diaryManager: DiaryManager

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var contrast

    @State private var enteredPincode: String = ""
    @State private var isUnlocking: Bool = false
    @State private var showError: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @State private var appeared = false
    @State private var didAttemptBiometric = false
    @State private var lockBreathing = false
    @State private var lockBounce = false

    let maxDigits = 4

    // Theme colors
    private let bgColor = AppTheme.bg
    private let dotActiveColor = AppTheme.accent
    private let dotInactiveColor = Color.white.opacity(0.15)

    var body: some View {
        ZStack {
            // Background
            bgColor.ignoresSafeArea()

            // Subtle noise texture overlay
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.03))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Lock icon
                lockIcon
                    .padding(.bottom, 24)

                // Title
                Text("Enter your space")
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Ullam is waiting for your thoughts")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 36)

                // Pincode dots
                pincodeDots
                    .padding(.bottom, 48)

                // Numpad
                NumpadView(
                    enteredValue: $enteredPincode,
                    maxDigits: maxDigits,
                    onBiometric: { attemptBiometricUnlock() },
                    onComplete: { attemptUnlock() }
                )

                Spacer()

                // Forgot pincode
                Button {
                    openDefaultDiary()
                } label: {
                    Text("Forgot Pincode?")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)

                // Footer branding
                Text("MIDNIGHT PAPER SECURE ACCESS")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.15))
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .disabled(isUnlocking)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            if !didAttemptBiometric && UserDefaults.standard.bool(forKey: "biometricEnabled") {
                didAttemptBiometric = true
                attemptBiometricUnlock()
            }
        }
    }

    // MARK: - Lock Icon

    private var lockIcon: some View {
        ZStack {
            // Breathing glow
            Circle()
                .fill(dotActiveColor.opacity(lockBreathing ? 0.1 : 0.03))
                .frame(width: lockBreathing ? 78 : 72, height: lockBreathing ? 78 : 72)
                .blur(radius: 6)

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 64, height: 64)

            Circle()
                .stroke(.white.opacity(lockBreathing ? 0.12 : 0.06), lineWidth: 1)
                .frame(width: 64, height: 64)

            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(dotActiveColor.opacity(0.8))
        }
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
        .scaleEffect(lockBounce ? 1.1 : 1.0)
        .accessibilityLabel("Locked diary")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                lockBreathing = true
            }
        }
    }

    // MARK: - Pincode Dots

    private var pincodeDots: some View {
        HStack(spacing: 20) {
            ForEach(0..<maxDigits, id: \.self) { index in
                let isFilled = index < enteredPincode.count
                ZStack {
                    // Glow behind filled dots
                    if isFilled {
                        Circle()
                            .fill(dotActiveColor.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .blur(radius: 6)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Circle()
                        .fill(isFilled ? dotActiveColor : dotInactiveColor)
                        .frame(width: 12, height: 12)
                        .scaleEffect(isFilled ? 1.0 : 0.75)
                }
                .frame(width: 24, height: 24)
                .scaleEffect(isFilled && index == enteredPincode.count - 1 ? 1.2 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: enteredPincode.count)
                // Stagger entrance
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.2 + Double(index) * 0.05), value: appeared)
            }
        }
        .offset(x: shakeOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pincode entry, \(enteredPincode.count) of \(maxDigits) digits entered")
        .accessibilityValue(showError ? "Incorrect pincode" : "")
    }

    // MARK: - Actions

    private func attemptUnlock() {
        guard !enteredPincode.isEmpty else { return }

        isUnlocking = true

        Task {
            let success = await diaryManager.unlockDiary(with: enteredPincode)
            isUnlocking = false

            if !success {
                triggerShake()
            }

            enteredPincode = ""
        }
    }

    private func openDefaultDiary() {
        if !diaryManager.openDefaultDiary() {
            triggerShake()
        }
    }

    private func attemptBiometricUnlock() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }

        isUnlocking = true

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your diary"
        ) { success, _ in
            DispatchQueue.main.async {
                isUnlocking = false
                if success {
                    if !diaryManager.openDefaultDiary() {
                        triggerShake()
                    }
                }
            }
        }
    }

    private func triggerShake() {
        withAnimation(.interactiveSpring(response: 0.05, dampingFraction: 0.3, blendDuration: 0.05)) {
            shakeOffset = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interactiveSpring(response: 0.05, dampingFraction: 0.3, blendDuration: 0.05)) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.interactiveSpring(response: 0.05, dampingFraction: 0.3, blendDuration: 0.05)) {
                shakeOffset = 8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.interactiveSpring(response: 0.05, dampingFraction: 0.3, blendDuration: 0.05)) {
                shakeOffset = -4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.5, blendDuration: 0.1)) {
                shakeOffset = 0
            }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var shake: Bool
    var animatableData: CGFloat {
        get { shake ? 1 : 0 }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard shake else { return ProjectionTransform(.identity) }
        let translation = sin(animatableData * .pi * 4) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    PincodeEntryView(diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext))
}
