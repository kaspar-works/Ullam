#if os(iOS)
import SwiftUI

struct ThrowbackCard: View {
    let entries: [(page: Page, title: String, body: String, yearsAgo: Int)]
    let onTapEntry: (Page) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    private var primary: (page: Page, title: String, body: String, yearsAgo: Int)? {
        entries.first
    }

    var body: some View {
        if let entry = primary {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xFDBA74).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFDBA74).opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("On this day, \(entry.yearsAgo) year\(entry.yearsAgo == 1 ? "" : "s") ago")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFDBA74).opacity(0.8))

                        if entries.count > 1 {
                            Text("\(entries.count) memories found")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.dimText)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.25)) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.dimText)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(AppTheme.subtle))
                    }
                }
                .padding(.bottom, 12)

                // Entry preview
                Button {
                    onTapEntry(entry.page)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        if !entry.title.isEmpty {
                            Text(entry.title)
                                .font(.custom("NewYork-Bold", size: 16, relativeTo: .headline))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)
                        }

                        if !entry.body.isEmpty {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color(hex: 0xFDBA74).opacity(0.25))
                                    .frame(width: 2)
                                    .clipShape(Capsule())

                                Text(String(entry.body.prefix(120)))
                                    .font(.custom("NewYork-Regular", size: 14, relativeTo: .body))
                                    .foregroundStyle(AppTheme.dimText)
                                    .lineSpacing(5)
                                    .lineLimit(3)
                                    .padding(.leading, 10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ThrowbackButtonStyle())

                // More entries indicator
                if entries.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(entries.dropFirst().prefix(3), id: \.page.id) { extra in
                            Text("\(extra.yearsAgo)y")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppTheme.dimText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(AppTheme.subtle)
                                )
                        }

                        Spacer()
                    }
                    .padding(.top, 10)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0xFDBA74).opacity(0.2),
                                        Color(hex: 0xFDBA74).opacity(0.05),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color(hex: 0xFDBA74).opacity(0.06), radius: 16, y: 6)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Button Style

private struct ThrowbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#endif // os(iOS)
