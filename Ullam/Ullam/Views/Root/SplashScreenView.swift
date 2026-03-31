import SwiftUI

struct SplashScreenView: View {
    var onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var contrast

    @State private var appeared = false
    @State private var lineHeight: CGFloat = 0
    @State private var glowPulse = false
    @State private var buttonPulse = false
    @State private var iconRotation: Double = 0

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d'th'"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.086, green: 0.106, blue: 0.157),
                    AppTheme.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo icon with glow
                ZStack {
                    // Breathing glow behind icon
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppTheme.accent.opacity(glowPulse ? 0.12 : 0.04))
                        .frame(width: glowPulse ? 72 : 64, height: glowPulse ? 72 : 64)
                        .blur(radius: 8)

                    RoundedRectangle(cornerRadius: 18)
                        .fill(AppTheme.subtle)
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.accent.opacity(glowPulse ? 0.2 : 0.05), lineWidth: 1)
                        )

                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                        .rotationEffect(.degrees(iconRotation))
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.5)
                .padding(.bottom, 16)

                // App name
                Text("Ullam")
                    .font(.custom("NewYork-Bold", size: 36, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .padding(.bottom, 24)
                    .accessibilityAddTraits(.isHeader)

                // Subtitle
                Text("THE NOCTURNAL SANCTUARY")
                    .font(.system(.caption2, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(contrast == .increased ? 0.5 : 0.25))
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(x: appeared ? 1 : 0.8)
                    .padding(.bottom, 12)

                // Animated line
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1, height: lineHeight)
                    .padding(.bottom, 24)

                Spacer()

                // Date
                Text(formattedDate)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.white.opacity(contrast == .increased ? 0.85 : 0.7))
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 4)

                Text("NIGHTFALL IS UPON US")
                    .font(.system(.caption2, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(contrast == .increased ? 0.45 : 0.2))
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 40)

                // Tap to open
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(.caption))
                        Text("TAP TO OPEN JOURNAL")
                            .font(.system(.caption2, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(.white.opacity(buttonPulse ? 0.55 : 0.35))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .stroke(.white.opacity(buttonPulse ? 0.2 : 0.08), lineWidth: 1)
                    )
                    .scaleEffect(buttonPulse ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open your journal")
                .accessibilityHint("Opens the diary to start writing")
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
                lineHeight = 40
                return
            }
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                iconRotation = -5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    iconRotation = 0
                }
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                lineHeight = 40
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.0)) {
                glowPulse = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.5)) {
                buttonPulse = true
            }
        }
    }
}

#Preview {
    SplashScreenView(onTap: {})
}
