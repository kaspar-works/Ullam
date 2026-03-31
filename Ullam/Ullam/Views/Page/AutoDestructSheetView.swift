#if os(iOS)
import SwiftUI

struct AutoDestructSheetView: View {
    let page: Page
    var onDismiss: () -> Void

    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    private let options: [(label: String, days: Int?, icon: String)] = [
        ("24 hours", 1, "clock.badge.xmark"),
        ("3 days", 3, "clock.arrow.circlepath"),
        ("7 days", 7, "calendar.badge.clock"),
        ("30 days", 30, "calendar"),
        ("Never", nil, "infinity"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xF87171).opacity(0.08))
                        .frame(width: 64, height: 64)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: 0xF87171).opacity(0.6))
                }
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appeared)

                VStack(spacing: 4) {
                    Text("Self-Destruct")
                        .font(.custom("NewYork-Bold", size: 20, relativeTo: .title3))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("This page will be permanently deleted after the chosen time.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.dimText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                if let destroyDate = page.autoDestructDate {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                        Text("Expires \(destroyDate.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: 0xF87171).opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0xF87171).opacity(0.08))
                    )
                }

                // Options
                VStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                        let isActive = isOptionActive(option)
                        Button {
                            if let days = option.days {
                                AutoDestructService.shared.setAutoDestruct(page: page, after: days)
                            } else {
                                AutoDestructService.shared.removeAutoDestruct(page: page)
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDismiss()
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(isActive ? Color(hex: 0xF87171) : AppTheme.dimText)
                                    .frame(width: 24)

                                Text(option.label)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(isActive ? AppTheme.primaryText : AppTheme.sage)

                                Spacer()

                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color(hex: 0xF87171))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isActive ? Color(hex: 0xF87171).opacity(0.06) : AppTheme.subtle)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isActive ? Color(hex: 0xF87171).opacity(0.15) : AppTheme.subtle, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15 + Double(idx) * 0.04), value: appeared)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    private func isOptionActive(_ option: (label: String, days: Int?, icon: String)) -> Bool {
        if option.days == nil {
            return page.autoDestructDate == nil
        }
        guard let destroyDate = page.autoDestructDate else { return false }
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: destroyDate).day ?? 0
        return daysRemaining == option.days
    }
}
#endif
