import SwiftUI

struct SplashScreenView: View {
    var onTap: () -> Void

    @State private var appeared = false
    @State private var lineHeight: CGFloat = 0

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
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    AppTheme.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo icon
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AppTheme.subtle)
                        .frame(width: 56, height: 56)

                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)
                .padding(.bottom, 16)

                // App name
                Text("Ullam")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 24)

                // Subtitle
                Text("THE NOCTURNAL SANCTUARY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.25))
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 12)

                // Animated line
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1, height: lineHeight)
                    .padding(.bottom, 24)

                Spacer()

                // Date
                Text(formattedDate)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 4)

                Text("NIGHTFALL IS UPON US")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.2))
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 40)

                // Tap to open
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("TAP TO OPEN JOURNAL")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                lineHeight = 40
            }
        }
    }
}

#Preview {
    SplashScreenView(onTap: {})
}
