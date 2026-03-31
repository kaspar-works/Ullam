#if os(iOS)
import SwiftUI
import SwiftData

struct CreateTimeCapsuleView: View {
    @Bindable var diaryManager: DiaryManager
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var unlockDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedPreset: Preset? = .oneWeek
    @State private var isSealing = false
    @State private var sealed = false
    @State private var appeared = false

    private let service = TimeCapsuleService.shared

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private var canSeal: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unlockDate > Date()
    }

    enum Preset: String, CaseIterable {
        case oneWeek = "1 Week"
        case oneMonth = "1 Month"
        case sixMonths = "6 Months"
        case oneYear = "1 Year"

        var calendarComponent: (Calendar.Component, Int) {
            switch self {
            case .oneWeek: return (.day, 7)
            case .oneMonth: return (.month, 1)
            case .sixMonths: return (.month, 6)
            case .oneYear: return (.year, 1)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                if sealed {
                    sealedConfirmation
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            // Prompt
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.accent.opacity(0.6))
                                    Text("YOUR MESSAGE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(AppTheme.accent.opacity(0.5))
                                }

                                TextEditor(text: $message)
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 180)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(AppTheme.subtle)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(AppTheme.subtle, lineWidth: 1)
                                            )
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if message.isEmpty {
                                            Text("Write a letter to your future self...")
                                                .font(.system(size: 16))
                                                .foregroundStyle(AppTheme.dimText)
                                                .padding(20)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }

                            // Quick presets
                            VStack(alignment: .leading, spacing: 12) {
                                Text("OPEN IN")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(AppTheme.dimText)

                                HStack(spacing: 10) {
                                    ForEach(Preset.allCases, id: \.self) { preset in
                                        Button {
                                            selectedPreset = preset
                                            let (component, value) = preset.calendarComponent
                                            if let date = Calendar.current.date(byAdding: component, value: value, to: Date()) {
                                                unlockDate = date
                                            }
                                        } label: {
                                            Text(preset.rawValue)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(selectedPreset == preset ? .white : AppTheme.mutedText)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 9)
                                                .background(
                                                    Capsule()
                                                        .fill(selectedPreset == preset ? AppTheme.accent.opacity(0.25) : AppTheme.subtle)
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(
                                                                    selectedPreset == preset ? AppTheme.accent.opacity(0.4) : AppTheme.subtle,
                                                                    lineWidth: 1
                                                                )
                                                        )
                                                )
                                        }
                                    }
                                }
                            }

                            // Date picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("OR PICK A DATE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(AppTheme.dimText)

                                DatePicker(
                                    "Unlock Date",
                                    selection: $unlockDate,
                                    in: minimumDate...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(AppTheme.accent)
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.subtle)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(AppTheme.subtle, lineWidth: 1)
                                        )
                                )
                                .onChange(of: unlockDate) { _, _ in
                                    selectedPreset = nil
                                }
                            }

                            // Unlock date display
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.accent.opacity(0.5))
                                Text("Will unlock on \(formattedDate(unlockDate))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                            .padding(.top, -8)

                            Spacer().frame(height: 20)

                            // Seal button
                            Button {
                                sealCapsule()
                            } label: {
                                HStack(spacing: 10) {
                                    if isSealing {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    Text("Seal Capsule")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(
                                            canSeal ?
                                            LinearGradient(
                                                colors: [AppTheme.accent, Color(hex: 0xC49340), AppTheme.gradientPink],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ) :
                                            LinearGradient(
                                                colors: [AppTheme.mutedText.opacity(0.15), AppTheme.subtle],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(canSeal ? AppTheme.dimText : AppTheme.subtle, lineWidth: 1)
                                        )
                                )
                                .shadow(color: canSeal ? AppTheme.accent.opacity(0.3) : .clear, radius: 20, y: 8)
                            }
                            .disabled(!canSeal || isSealing)

                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Time Capsule")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Sealed Confirmation

    private var sealedConfirmation: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0)

                Circle()
                    .fill(AppTheme.accent.opacity(0.06))
                    .frame(width: 96, height: 96)
                    .scaleEffect(appeared ? 1 : 0)

                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                    .scaleEffect(appeared ? 1 : 0)
                    .rotationEffect(.degrees(appeared ? 0 : -90))
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

            VStack(spacing: 8) {
                Text("Capsule Sealed")
                    .font(.custom("NewYork-Bold", size: 24, relativeTo: .title2))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Your message will unlock on\n\(formattedDate(unlockDate))")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.dimText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(AppTheme.accent.opacity(0.2))
                            .overlay(Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
                    )
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
            .padding(.bottom, 40)
        }
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
        }
    }

    // MARK: - Actions

    private func sealCapsule() {
        guard let diary = diaryManager.currentDiary else { return }
        isSealing = true

        let context = DataController.shared.container.mainContext
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = service.createCapsule(diary: diary, message: trimmedMessage, unlockDate: unlockDate, context: context)

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.easeOut(duration: 0.3)) {
            isSealing = false
            sealed = true
            appeared = false
        }
        // Re-trigger appearance animations for the sealed state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { appeared = true }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

#endif // os(iOS)
