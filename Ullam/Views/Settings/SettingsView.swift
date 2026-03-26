import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var iCloudSync: Bool = true
    @State private var biometricEnabled: Bool = false
    @State private var themeMode: ThemeMode = .dark
    @State private var paperTextureIntensity: Double = 0.5
    @State private var editingDiaryName: Bool = false
    @State private var newDiaryName: String = ""
    @State private var showPincodeSetup: Bool = false
    @State private var pincodeSetupMode: PincodeSetupMode = .setup
    @State private var isExporting: Bool = false

    enum ThemeMode: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case auto = "Auto"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Ullam Preferences")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                Text("Tailor your nocturnal sanctuary to your rhythm. All changes are\nautomatically synced to your cloud account.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(3)
                    .padding(.bottom, 36)

                // General
                sectionHeader(icon: "slider.horizontal.3", title: "General")
                    .padding(.bottom, 16)

                generalSection
                    .padding(.bottom, 36)

                // Privacy & Security
                sectionHeader(icon: "lock.fill", title: "Privacy & Security")
                    .padding(.bottom, 16)

                privacySection
                    .padding(.bottom, 36)

                // Data & Backups
                sectionHeader(icon: "externaldrive.fill", title: "Data & Backups")
                    .padding(.bottom, 16)

                dataSection
                    .padding(.bottom, 36)

                // Personalization
                sectionHeader(icon: "paintbrush.fill", title: "Personalization")
                    .padding(.bottom, 16)

                personalizationSection
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            iCloudSync = DataController.shared.iCloudEnabled
            biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        }
        .alert("Edit Diary Name", isPresented: $editingDiaryName) {
            TextField("Diary Name", text: $newDiaryName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let diary = diaryManager.currentDiary, !newDiaryName.isEmpty {
                    diary.plaintextName = newDiaryName
                    diary.modifiedAt = Date()
                }
            }
        } message: {
            Text("Enter a new name for this diary.")
        }
        .sheet(isPresented: $showPincodeSetup) {
            NavigationStack {
                PincodeSetupView(diaryManager: diaryManager, mode: pincodeSetupMode)
            }
            .frame(minWidth: 420, minHeight: 400)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(spacing: 0) {
            // iCloud Sync
            settingsRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sync")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Keep your journals updated across Mac, iPad, and iPhone.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }

                Spacer()

                Toggle("", isOn: $iCloudSync)
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent)
                    .labelsHidden()
                    .onChange(of: iCloudSync) { _, newValue in
                        // Update current diary preference
                        if let diary = diaryManager.currentDiary {
                            diary.storagePreference = newValue ? .iCloud : .local
                            diary.modifiedAt = Date()
                        }
                        // Persist global iCloud setting
                        DataController.shared.iCloudEnabled = newValue
                        DataController.shared.save()
                    }
            }

            settingsDivider

            // Default Diary
            settingsRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Diary")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Set the primary journal for new nocturnal entries.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }

                Spacer()

                Menu {
                    Button(diaryManager.currentDiary?.name ?? "Default") {}
                } label: {
                    HStack(spacing: 4) {
                        Text(diaryManager.currentDiary?.name ?? "Default")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(AppTheme.subtle)
                    )
                }
            }

            settingsDivider

            // Theme Mode
            settingsRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Theme Mode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Choose how Midnight Paper appears in your space.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.dimText)
                }

                Spacer()

                HStack(spacing: 0) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                themeMode = mode
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: themeMode == mode ? .semibold : .regular))
                                .foregroundStyle(themeMode == mode ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    themeMode == mode ?
                                    AppTheme.accent.opacity(0.3) : .clear
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    Capsule().fill(AppTheme.subtle)
                )
                .clipShape(Capsule())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.subtle)
        )
    }

    // MARK: - Privacy & Security

    private var privacySection: some View {
        HStack(spacing: 12) {
            // Biometric Unlock
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "touchid")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.5))

                Text("Biometric Unlock")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Use Touch ID or Face ID to unlock your sanctuary.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(2)

                Spacer()

                Toggle("", isOn: $biometricEnabled)
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent)
                    .labelsHidden()
                    .onChange(of: biometricEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "biometricEnabled")
                    }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.04), lineWidth: 1)
                    )
            )

            // Pincode Access
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }

                Text("Pincode Access")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("A secondary layer of protection for your private diaries.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(2)

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    if diaryManager.currentDiary?.isProtected == true {
                        Button {
                            pincodeSetupMode = .change
                            showPincodeSetup = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Change PIN")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            pincodeSetupMode = .remove
                            showPincodeSetup = true
                        } label: {
                            Text("Remove PIN")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            pincodeSetupMode = .setup
                            showPincodeSetup = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Set Up PIN")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Data & Backups

    private var dataSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Archive Your Thoughts")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("Export your entire collection into high-quality PDF or\nMarkdown formats for offline safekeeping.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(2)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {} label: {
                    Text("Backup Now")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(AppTheme.subtle)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    isExporting = true
                    Task {
                        await exportDiaryAsPDF()
                        isExporting = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isExporting ? "Exporting..." : "Export Data")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(AppTheme.accent.opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isExporting)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.subtle)
        )
    }

    // MARK: - Personalization

    private var personalizationSection: some View {
        HStack(spacing: 0) {
            // Left: text content
            VStack(alignment: .leading, spacing: 12) {
                Text("Tactile Experience")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)

                Text("Customize the paper grain, line spacing, and ink weight to replicate the feeling of your favorite physical notebook.")
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.5))
                    .lineSpacing(3)

                Spacer()

                // Slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAPER TEXTURE INTENSITY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.black.opacity(0.35))

                    Slider(value: $paperTextureIntensity, in: 0...1)
                        .tint(.black.opacity(0.6))
                }

                Button {} label: {
                    Text("Open Journal Lab")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(.black.opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: notebook illustration
            ZStack {
                // Stacked pages
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.88, green: 0.86, blue: 0.82))
                    .frame(width: 140, height: 180)
                    .rotationEffect(.degrees(5))
                    .offset(x: 8, y: -4)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.86))
                    .frame(width: 140, height: 180)
                    .overlay(
                        VStack(spacing: 8) {
                            ForEach(0..<8, id: \.self) { _ in
                                Rectangle()
                                    .fill(.black.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                        .padding(16)
                    )
            }
            .padding(.trailing, 28)
            .padding(.vertical, 20)
        }
        .frame(minHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.cardBg)
        )
    }

    // MARK: - Export

    private func exportDiaryAsPDF() async {
        let diaryName = diaryManager.currentDiary?.name ?? "Diary"
        let pageData = await diaryManager.decryptAllPagesForExport()

        guard !pageData.isEmpty,
              let pdfData = PDFExporter.exportPages(pageData, diaryName: diaryName) else {
            return
        }

        #if os(macOS)
        await MainActor.run {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "\(diaryName).pdf"
            panel.title = "Export Diary as PDF"
            panel.prompt = "Export"

            if panel.runModal() == .OK, let url = panel.url {
                try? pdfData.write(to: url)
            }
        }
        #endif
    }

    // MARK: - Helpers

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 16) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var settingsDivider: some View {
        Divider()
            .opacity(0.08)
            .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        SettingsView(
            diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext),
            showPincodeOverlay: .constant(false)
        )
    }
}
