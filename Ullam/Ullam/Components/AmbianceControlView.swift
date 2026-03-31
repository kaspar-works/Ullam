#if os(iOS)
import SwiftUI

// MARK: - Ambiance Control View

struct AmbianceControlView: View {
    var ambianceService: AmbianceService = .shared

    @State private var isExpanded: Bool = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Group {
            if isExpanded {
                expandedControl
            } else {
                collapsedControl
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
    }

    // MARK: - Collapsed (Speaker Icon)

    private var collapsedControl: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isExpanded = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.7))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().stroke(AppTheme.subtle, lineWidth: 1)
                    )

                if ambianceService.isPlaying {
                    // Pulsing glow for active state
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 38, height: 38)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                pulseScale = 1.15
                            }
                        }
                        .onDisappear { pulseScale = 1.0 }
                }

                Image(systemName: ambianceService.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ambianceService.isPlaying ? AppTheme.accent : AppTheme.dimText)
            }
        }
        .buttonStyle(AmbianceBtnStyle())
    }

    // MARK: - Expanded (Full Control)

    private var expandedControl: some View {
        VStack(spacing: 10) {
            // Header row
            HStack {
                Text("AMBIANCE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.dimText)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        isExpanded = false
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.dimText)
                        .frame(width: 22, height: 22)
                        .background(AppTheme.subtle)
                        .clipShape(Circle())
                }
                .buttonStyle(AmbianceBtnStyle())
            }

            // Sound buttons
            HStack(spacing: 8) {
                ForEach(AmbianceService.availableSounds, id: \.id) { sound in
                    soundButton(sound: sound)
                }
            }

            // Volume slider
            if ambianceService.isPlaying || ambianceService.currentSound != nil {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.dimText)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.subtle)
                                .frame(height: 3)

                            Capsule()
                                .fill(AppTheme.accent.opacity(0.6))
                                .frame(width: max(0, geo.size.width * ambianceService.volume), height: 3)

                            // Drag thumb
                            Circle()
                                .fill(.white)
                                .frame(width: 10, height: 10)
                                .shadow(color: AppTheme.accent.opacity(0.3), radius: 4)
                                .offset(x: max(0, min(geo.size.width - 10, geo.size.width * ambianceService.volume - 5)))
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let pct = max(0, min(1, value.location.x / geo.size.width))
                                    ambianceService.setVolume(pct)
                                }
                        )
                    }
                    .frame(height: 16)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.dimText)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // "Sound pack not installed" hint
            if let sound = ambianceService.currentSound, !ambianceService.isPlaying {
                if !ambianceService.isSoundAvailable(sound) {
                    Text("Sound pack not installed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.6))
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.mutedText.opacity(0.15), AppTheme.subtle],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
        )
        .frame(maxWidth: 280)
    }

    // MARK: - Sound Button

    private func soundButton(sound: (id: String, label: String, icon: String)) -> some View {
        let isActive = ambianceService.currentSound == sound.id && ambianceService.isPlaying

        return Button {
            ambianceService.toggle(sound.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isActive ? AppTheme.accent.opacity(0.2) : AppTheme.subtle)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(isActive ? AppTheme.accent.opacity(0.5) : AppTheme.subtle, lineWidth: 1.5)
                        )

                    if isActive {
                        // Pulsing outer glow ring
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.2), lineWidth: 2)
                            .frame(width: 46, height: 46)
                            .scaleEffect(pulseScale)
                    }

                    Image(systemName: sound.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isActive ? AppTheme.accent : AppTheme.dimText)
                }

                Text(sound.label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isActive ? AppTheme.accent.opacity(0.8) : AppTheme.dimText)
            }
        }
        .buttonStyle(AmbianceBtnStyle())
    }
}

// MARK: - Button Style

private struct AmbianceBtnStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#endif
