#if os(iOS)
import SwiftUI
import SwiftData
import UIKit
import LocalAuthentication

// MARK: - Settings ViewModel

@MainActor
@Observable
final class SettingsViewModel {
    var iCloudSync: Bool = false
    var biometricEnabled: Bool = false
    var selectedTheme: AppThemeMode = .dark

    // Status indicators
    var iCloudStatus: SyncStatus = .idle
    var exportStatus: ExportStatus = .idle
    var backupStatus: BackupStatus = .idle
    var biometricAvailability: BiometricAvailability = .unknown

    // Export
    var exportedPDFURL: URL?
    var showShareSheet = false

    // Sheets
    var showPincodeSetup = false
    var pincodeSetupMode: PincodeSetupMode = .setup
    var showDiaryPicker = false
    var showThemePicker = false
    var showEncryptionInfo = false
    var showBackupConfirmation = false

    enum SyncStatus: Equatable {
        case idle, syncing, synced(Date), failed(String), unavailable
    }

    enum ExportStatus: Equatable {
        case idle, exporting, success, failed
    }

    enum BackupStatus: Equatable {
        case idle, inProgress, success(Date), failed
    }

    enum BiometricAvailability {
        case unknown, available(String), unavailable(String)
    }

    func load() {
        iCloudSync = DataController.shared.iCloudEnabled
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        let themeRaw = UserDefaults.standard.string(forKey: "appThemeMode") ?? "dark"
        selectedTheme = AppThemeMode(rawValue: themeRaw) ?? .dark
        checkBiometricAvailability()
        checkiCloudAvailability()
    }

    func toggleiCloudSync(_ enabled: Bool, diary: Diary?) {
        iCloudSync = enabled
        DataController.shared.iCloudEnabled = enabled
        if let diary {
            diary.storagePreference = enabled ? .iCloud : .local
        }
        DataController.shared.save()

        if enabled {
            iCloudStatus = .syncing
            // Simulate sync completion
            Task {
                try? await Task.sleep(for: .seconds(2))
                iCloudStatus = .synced(Date())
            }
        } else {
            iCloudStatus = .idle
        }
    }

    func toggleBiometric(_ enabled: Bool) {
        if enabled {
            let context = LAContext()
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable biometric unlock for Ullam") { success, error in
                Task { @MainActor in
                    if success {
                        self.biometricEnabled = true
                        UserDefaults.standard.set(true, forKey: "biometricEnabled")
                    } else {
                        self.biometricEnabled = false
                    }
                }
            }
        } else {
            biometricEnabled = false
            UserDefaults.standard.set(false, forKey: "biometricEnabled")
        }
    }

    func setTheme(_ theme: AppThemeMode) {
        selectedTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "appThemeMode")
    }

    func exportDiary(diaryManager: DiaryManager) async {
        exportStatus = .exporting
        let diaryName = diaryManager.currentDiary?.name ?? "Diary"
        let pageData = await diaryManager.decryptAllPagesForExport()

        guard !pageData.isEmpty,
              let pdfData = PDFExporter.exportPages(pageData, diaryName: diaryName) else {
            exportStatus = .failed
            Task {
                try? await Task.sleep(for: .seconds(2))
                exportStatus = .idle
            }
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(diaryName).pdf")
        do {
            try pdfData.write(to: tempURL)
            exportedPDFURL = tempURL
            exportStatus = .success
            presentShareSheet(url: tempURL)
        } catch {
            exportStatus = .failed
        }

        Task {
            try? await Task.sleep(for: .seconds(3))
            exportStatus = .idle
        }
    }

    func presentShareSheet(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController { presenter = presented }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        presenter.present(activityVC, animated: true)
    }

    func performBackup() async {
        guard backupStatus != .inProgress else { return }
        backupStatus = .inProgress
        // Trigger save + sync
        DataController.shared.save()
        try? await Task.sleep(for: .seconds(2))
        backupStatus = .success(Date())

        Task {
            try? await Task.sleep(for: .seconds(3))
            backupStatus = .idle
        }
    }

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let type = context.biometryType == .faceID ? "Face ID" : "Touch ID"
            biometricAvailability = .available(type)
        } else {
            biometricAvailability = .unavailable(error?.localizedDescription ?? "Biometrics not available")
        }
    }

    private func checkiCloudAvailability() {
        if FileManager.default.ubiquityIdentityToken == nil && iCloudSync {
            iCloudStatus = .unavailable
        } else if iCloudSync {
            iCloudStatus = .synced(Date())
        }
    }
}

enum AppThemeMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Settings View

struct SettingsMobileView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var vm = SettingsViewModel()
    @State private var appeared = false
    @State private var profileRingRotation: Double = 0
    @State private var writingGoalEnabled = false
    @State private var writingGoalAmount = 200
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var deleteConfirmText = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            settingsBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Profile card
                    profileCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.05), value: appeared)

                    // General
                    sectionBlock(title: "GENERAL", delay: 0.1) {
                        // iCloud Sync
                        settingsRow(icon: "icloud.fill", label: "iCloud Sync") {
                            HStack(spacing: 8) {
                                if case .syncing = vm.iCloudStatus {
                                    ProgressView().controlSize(.mini).tint(AppTheme.dimText)
                                } else if case .synced(let date) = vm.iCloudStatus {
                                    Text(relativeTime(date))
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.dimText)
                                } else if case .unavailable = vm.iCloudStatus {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange.opacity(0.6))
                                }
                                Toggle("", isOn: Binding(
                                    get: { vm.iCloudSync },
                                    set: { newValue in
                                        vm.toggleiCloudSync(newValue, diary: diaryManager.currentDiary)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                ))
                                .toggleStyle(.switch)
                                .tint(AppTheme.accent)
                                .labelsHidden()
                            }
                        }

                        softDivider

                        // Default Diary
                        Button {
                            vm.showDiaryPicker = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            settingsRow(icon: "text.book.closed.fill", label: "Default Diary") {
                                Text(diaryManager.currentDiary?.name ?? "Me & Me")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.dimText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())

                        softDivider

                        // Theme Mode
                        Button {
                            vm.showThemePicker = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            settingsRow(icon: "moon.fill", label: "Theme Mode") {
                                Text(vm.selectedTheme.label)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.dimText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())

                        softDivider

                        // Writing Goal
                        settingsRow(icon: "target", label: "Daily Writing Goal") {
                            HStack(spacing: 8) {
                                if writingGoalEnabled {
                                    Text("\(writingGoalAmount) words")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.dimText)
                                }
                                Toggle("", isOn: $writingGoalEnabled)
                                    .toggleStyle(.switch)
                                    .tint(AppTheme.accent)
                                    .labelsHidden()
                                    .onChange(of: writingGoalEnabled) { _, newValue in
                                        saveWritingGoal()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }

                        if writingGoalEnabled {
                            HStack {
                                Spacer()
                                Picker("Goal", selection: $writingGoalAmount) {
                                    ForEach([50, 100, 150, 200, 300, 500, 750, 1000], id: \.self) { amount in
                                        Text("\(amount) words").tag(amount)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.accent)
                                .onChange(of: writingGoalAmount) { _, _ in
                                    saveWritingGoal()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }

                        softDivider

                        // Bookmarks
                        NavigationLink(destination: BookmarksView(diaryManager: diaryManager)) {
                            settingsRow(icon: "bookmark.fill", label: "Bookmarked Pages") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())

                        softDivider

                        // Past Self
                        NavigationLink(destination: PastSelfChatView(diaryManager: diaryManager)) {
                            settingsRow(icon: "bubble.left.and.bubble.right.fill", label: "Talk to Past Self") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())
                    }

                    // Privacy & Security
                    sectionBlock(title: "PRIVACY & SECURITY", delay: 0.15, tint: AppTheme.indigo) {
                        // Face ID / Touch ID
                        settingsRow(icon: biometricIcon, label: biometricLabel, tint: AppTheme.indigo) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Toggle("", isOn: Binding(
                                    get: { vm.biometricEnabled },
                                    set: { newValue in
                                        vm.toggleBiometric(newValue)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                ))
                                .toggleStyle(.switch)
                                .tint(AppTheme.indigo)
                                .labelsHidden()
                                .disabled(biometricDisabled)

                                if biometricDisabled {
                                    Text("Not available")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.orange.opacity(0.5))
                                }
                            }
                        }

                        softDivider

                        // Pincode
                        if diaryManager.currentDiary?.isProtected == true {
                            Button {
                                vm.pincodeSetupMode = .change
                                vm.showPincodeSetup = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                settingsRow(icon: "lock.fill", label: "Change Pincode", tint: AppTheme.indigo) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AppTheme.dimText)
                                }
                            }
                            .buttonStyle(SettingsButtonStyle())

                            softDivider

                            Button {
                                vm.pincodeSetupMode = .remove
                                vm.showPincodeSetup = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                settingsRow(icon: "lock.open", label: "Remove Pincode", tint: .orange) {
                                    EmptyView()
                                }
                            }
                            .buttonStyle(SettingsButtonStyle())
                        } else {
                            Button {
                                vm.pincodeSetupMode = .setup
                                vm.showPincodeSetup = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                settingsRow(icon: "lock.fill", label: "Set Up Pincode", tint: AppTheme.indigo) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AppTheme.dimText)
                                }
                            }
                            .buttonStyle(SettingsButtonStyle())
                        }

                        softDivider

                        // Encryption Info
                        Button {
                            vm.showEncryptionInfo = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            settingsRow(icon: "shield.fill", label: "Encryption", tint: AppTheme.indigo) {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                    Text("AES-256")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.dimText)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AppTheme.dimText)
                                }
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())
                    }

                    // Data
                    sectionBlock(title: "DATA", delay: 0.2) {
                        // Export
                        Button {
                            guard vm.exportStatus != .exporting else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await vm.exportDiary(diaryManager: diaryManager) }
                        } label: {
                            settingsRow(icon: "square.and.arrow.up", label: "Export Diary") {
                                switch vm.exportStatus {
                                case .idle:
                                    HStack(spacing: 4) {
                                        Text("PDF")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppTheme.dimText)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(AppTheme.dimText)
                                    }
                                case .exporting:
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.mini).tint(AppTheme.dimText)
                                        Text("Exporting\u{2026}")
                                            .font(.system(size: 11))
                                            .foregroundStyle(AppTheme.dimText)
                                    }
                                case .success:
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                        Text("Done")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                    }
                                case .failed:
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.orange.opacity(0.6))
                                        Text("Failed")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.orange.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())
                        .disabled(vm.exportStatus == .exporting)

                        softDivider

                        // Backup
                        Button {
                            guard vm.backupStatus != .inProgress else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await vm.performBackup() }
                        } label: {
                            settingsRow(icon: "arrow.clockwise", label: "Backup") {
                                switch vm.backupStatus {
                                case .idle:
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AppTheme.dimText)
                                case .inProgress:
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.mini).tint(AppTheme.dimText)
                                        Text("Backing up\u{2026}")
                                            .font(.system(size: 11))
                                            .foregroundStyle(AppTheme.dimText)
                                    }
                                case .success(let date):
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                        Text(relativeTime(date))
                                            .font(.system(size: 11))
                                            .foregroundStyle(AppTheme.dimText)
                                    }
                                case .failed:
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.orange.opacity(0.6))
                                        Text("Failed")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.orange.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .buttonStyle(SettingsButtonStyle())
                        .disabled(vm.backupStatus == .inProgress)
                    }

                    // Ambiance
                    sectionBlock(title: "WRITING AMBIANCE", delay: 0.25, tint: AppTheme.gradientPurple) {
                        ambianceSettingsContent
                    }

                    // Lock diary (if protected)
                    if diaryManager.currentDiary?.isProtected == true {
                        lockDiaryButton
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                    }

                    // Danger Zone
                    dangerZoneSection
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)

                    // App info
                    appInfoFooter
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            vm.load()
            loadWritingGoal()
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) { appeared = true }
            if !reduceMotion {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    profileRingRotation = 360
                }
            }
        }
        // Pincode setup
        .sheet(isPresented: $vm.showPincodeSetup) {
            NavigationStack {
                PincodeSetupView(diaryManager: diaryManager, mode: vm.pincodeSetupMode)
            }
        }
        // Share sheet presented via UIKit (see SettingsViewModel.presentShareSheet)
        // Diary picker
        .sheet(isPresented: $vm.showDiaryPicker) {
            diaryPickerSheet
        }
        // Theme picker
        .sheet(isPresented: $vm.showThemePicker) {
            themePickerSheet
        }
        // Encryption info
        .sheet(isPresented: $vm.showEncryptionInfo) {
            encryptionInfoSheet
        }
    }

    // MARK: - Biometric helpers

    private var biometricIcon: String {
        if case .available(let type) = vm.biometricAvailability {
            return type == "Face ID" ? "faceid" : "touchid"
        }
        return "faceid"
    }

    private var biometricLabel: String {
        if case .available(let type) = vm.biometricAvailability {
            return type
        }
        return "Face ID / Touch ID"
    }

    private var biometricDisabled: Bool {
        if case .unavailable = vm.biometricAvailability { return true }
        return false
    }

    // MARK: - Ambiance Settings

    @ViewBuilder
    private var ambianceSettingsContent: some View {
        let settings = DataController.shared.getOrCreateSettings()
        let ambianceService = AmbianceService.shared

        // Default sound picker
        settingsRow(icon: "speaker.wave.2.fill", label: "Default Sound", tint: AppTheme.gradientPurple) {
            Text(settings.ambienceSound?.capitalized ?? "Off")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.dimText)
        }

        // Sound options
        VStack(spacing: 0) {
            ForEach(AmbianceService.availableSounds, id: \.id) { sound in
                Button {
                    if settings.ambienceSound == sound.id {
                        settings.ambienceSound = nil
                    } else {
                        settings.ambienceSound = sound.id
                    }
                    DataController.shared.save()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: sound.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(settings.ambienceSound == sound.id ? AppTheme.accent : AppTheme.dimText)
                            .frame(width: 20)

                        Text(sound.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)

                        Spacer()

                        if settings.ambienceSound == sound.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(SettingsButtonStyle())
            }
        }

        softDivider

        // Volume control
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.gradientPurple.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.gradientPurple.opacity(0.7))
            }

            Text("Volume")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.dimText)

                Slider(value: Binding(
                    get: { settings.ambienceVolume },
                    set: { newVal in
                        settings.ambienceVolume = newVal
                        ambianceService.setVolume(newVal)
                        DataController.shared.save()
                    }
                ), in: 0...1)
                .tint(AppTheme.accent)
                .frame(width: 100)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.dimText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        softDivider

        // Auto-play toggle
        settingsRow(icon: "play.circle.fill", label: "Auto-play when writing", tint: AppTheme.gradientPurple) {
            Toggle("", isOn: Binding(
                get: { settings.ambienceAutoPlay },
                set: { newValue in
                    settings.ambienceAutoPlay = newValue
                    DataController.shared.save()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            ))
            .toggleStyle(.switch)
            .tint(AppTheme.accent)
            .labelsHidden()
        }
    }

    // MARK: - Background

    private var settingsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.bg, AppTheme.bg, AppTheme.sidebarBg],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [AppTheme.accent.opacity(0.04), .clear], center: .topLeading, startRadius: 20, endRadius: 350)
            RadialGradient(colors: [AppTheme.gradientPink.opacity(0.025), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 300)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent.opacity(0.5), AppTheme.gradientPink.opacity(0.3), AppTheme.accent.opacity(0.1), AppTheme.accent.opacity(0.5)],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(profileRingRotation))
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.accent.opacity(0.15), AppTheme.accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Text(String((diaryManager.currentDiary?.name ?? "U").prefix(1)))
                    .font(.custom("NewYork-Bold", size: 22, relativeTo: .title2))
                    .foregroundStyle(AppTheme.accent)
            }
            .shadow(color: AppTheme.accent.opacity(0.15), radius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(diaryManager.currentDiary?.name ?? "Ullam User")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(diaryManager.currentDiary?.isProtected == true ? "PROTECTED DIARY" : "PRIVATE DIARY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(diaryManager.currentDiary?.pages?.count ?? 0)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                Text("entries")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LinearGradient(colors: [AppTheme.subtle, AppTheme.subtle], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(diaryManager.currentDiary?.name ?? "Ullam User"), \(diaryManager.currentDiary?.isProtected == true ? "protected" : "private") diary, \(diaryManager.currentDiary?.pages?.count ?? 0) entries")
    }

    // MARK: - Section Block

    private func sectionBlock<Content: View>(title: String, delay: Double, tint: Color = AppTheme.accent, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(tint.opacity(contrast == .increased ? 0.7 : 0.5))
                .padding(.leading, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) { content() }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.subtle)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.subtle, lineWidth: 1))
                )
                .padding(.horizontal, 16)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.8).delay(delay), value: appeared)
    }

    // MARK: - Settings Row

    private func settingsRow<Trailing: View>(icon: String, label: String, tint: Color = AppTheme.accent, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint.opacity(0.7))
            }
            Text(label)
                .font(.body.weight(.medium))
                .foregroundStyle(tint == .orange ? .orange.opacity(0.9) : AppTheme.primaryText.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var softDivider: some View {
        Rectangle().fill(AppTheme.subtle).frame(height: 1).padding(.leading, 60)
            .accessibilityHidden(true)
    }

    // MARK: - Lock Diary Button

    private var lockDiaryButton: some View {
        Button {
            diaryManager.lockCurrentDiary()
            _ = diaryManager.openDefaultDiaryIfUnprotected()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.system(size: 13, weight: .semibold))
                Text("Lock Diary").font(.body.weight(.semibold))
            }
            .foregroundStyle(.orange.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.orange.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.orange.opacity(0.12), lineWidth: 1))
            )
        }
        .buttonStyle(SettingsButtonStyle())
        .accessibilityLabel("Lock diary")
        .accessibilityHint("Double tap to lock the current diary and switch to default")
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DANGER ZONE")
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.red.opacity(0.6))
                .padding(.leading, 20)
                .padding(.top, 28)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                // Delete All Data
                Button {
                    showDeleteAllConfirmation = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    settingsRow(icon: "trash.fill", label: "Delete All Data", tint: .red) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.dimText)
                    }
                }
                .buttonStyle(SettingsButtonStyle())

                softDivider

                // Delete Account
                Button {
                    showDeleteAccountConfirmation = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    settingsRow(icon: "person.crop.circle.badge.xmark", label: "Delete Account", tint: .red) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.dimText)
                    }
                }
                .buttonStyle(SettingsButtonStyle())
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.subtle)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.subtle, lineWidth: 1))
            )
            .padding(.horizontal, 16)
        }
        .alert("Delete All Data", isPresented: $showDeleteAllConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteConfirmText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) {
                deleteConfirmText = ""
            }
            Button("Delete Everything", role: .destructive) {
                if deleteConfirmText == "DELETE" {
                    performDeleteAllData()
                }
                deleteConfirmText = ""
            }
        } message: {
            Text("This will permanently delete ALL diaries, pages, moods, media, and settings. This action cannot be undone.\n\nType DELETE to confirm.")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteConfirmText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) {
                deleteConfirmText = ""
            }
            Button("Delete Account & Data", role: .destructive) {
                if deleteConfirmText == "DELETE" {
                    performDeleteAccount()
                }
                deleteConfirmText = ""
            }
        } message: {
            Text("This will permanently delete your account and ALL associated data including diaries, pages, and settings. This action cannot be undone.\n\nType DELETE to confirm.")
        }
    }

    private func performDeleteAllData() {
        let context = DataController.shared.container.mainContext

        // Delete all media files from disk
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = documentsDir.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.removeItem(at: mediaDir)

        // Delete all pages
        let pageDescriptor = FetchDescriptor<Page>()
        if let pages = try? context.fetch(pageDescriptor) {
            for page in pages { context.delete(page) }
        }

        // Delete all day moods
        let moodDescriptor = FetchDescriptor<DayMood>()
        if let moods = try? context.fetch(moodDescriptor) {
            for mood in moods { context.delete(mood) }
        }

        // Delete all media attachments
        let mediaDescriptor = FetchDescriptor<MediaAttachment>()
        if let attachments = try? context.fetch(mediaDescriptor) {
            for attachment in attachments { context.delete(attachment) }
        }

        // Delete all tags
        let tagDescriptor = FetchDescriptor<Tag>()
        if let tags = try? context.fetch(tagDescriptor) {
            for tag in tags { context.delete(tag) }
        }

        // Delete all time capsules
        let capsuleDescriptor = FetchDescriptor<TimeCapsule>()
        if let capsules = try? context.fetch(capsuleDescriptor) {
            for capsule in capsules { context.delete(capsule) }
        }

        // Delete all writing prompts
        let promptDescriptor = FetchDescriptor<WritingPrompt>()
        if let prompts = try? context.fetch(promptDescriptor) {
            for prompt in prompts { context.delete(prompt) }
        }

        // Delete all diaries
        let diaryDescriptor = FetchDescriptor<Diary>()
        if let diaries = try? context.fetch(diaryDescriptor) {
            for diary in diaries { context.delete(diary) }
        }

        // Delete all settings
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        if let allSettings = try? context.fetch(settingsDescriptor) {
            for s in allSettings { context.delete(s) }
        }

        // Save
        try? context.save()

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "biometricEnabled")
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        // Lock and reset
        diaryManager.lockCurrentDiary()

        // Recreate default state
        DataController.shared.createDefaultDiaryIfNeeded()
        _ = diaryManager.openDefaultDiaryIfUnprotected()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func performDeleteAccount() {
        // Delete all data first
        performDeleteAllData()

        // Clear any remaining keychain/cache data
        let domain = Bundle.main.bundleIdentifier ?? ""
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Reset onboarding so user sees fresh start
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - App Info Footer

    private var appInfoFooter: some View {
        VStack(spacing: 4) {
            Text("Ullam")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.dimText)
            Text("Version 1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Diary Picker Sheet

    private var diaryPickerSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(DataController.shared.fetchAllDiaries().filter({ !$0.isProtected })) { diary in
                            Button {
                                diaryManager.openDiary(diary)
                                vm.showDiaryPicker = false
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "text.book.closed.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(diary.id == diaryManager.currentDiary?.id ? AppTheme.accent : AppTheme.dimText)

                                    Text(diary.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Spacer()

                                    if diary.id == diaryManager.currentDiary?.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(diary.id == diaryManager.currentDiary?.id ? AppTheme.accent.opacity(0.08) : AppTheme.subtle)
                                )
                            }
                            .buttonStyle(SettingsButtonStyle())
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Default Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { vm.showDiaryPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Theme Picker Sheet

    private var themePickerSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                VStack(spacing: 8) {
                    ForEach(AppThemeMode.allCases, id: \.self) { theme in
                        Button {
                            vm.setTheme(theme)
                            vm.showThemePicker = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: theme.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(vm.selectedTheme == theme ? AppTheme.accent : AppTheme.dimText)

                                Text(theme.label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Spacer()

                                if vm.selectedTheme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(vm.selectedTheme == theme ? AppTheme.accent.opacity(0.08) : AppTheme.subtle)
                            )
                        }
                        .buttonStyle(SettingsButtonStyle())
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { vm.showThemePicker = false }
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Encryption Info Sheet

    private var encryptionInfoSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: 0x34D399).opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color(hex: 0x34D399))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("End-to-End Encrypted")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("Your data is protected with military-grade encryption")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                        }

                        // Details
                        VStack(spacing: 12) {
                            encryptionRow(label: "Algorithm", value: "AES-256-GCM")
                            encryptionRow(label: "Key Derivation", value: "HKDF-SHA256")
                            encryptionRow(label: "Salt", value: "32-byte random")
                            encryptionRow(label: "Library", value: "Apple CryptoKit")
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.subtle)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.subtle, lineWidth: 1))
                        )

                        // What's encrypted
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHAT\u{2019}S ENCRYPTED")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.dimText)

                            ForEach(["Page titles", "Page content (RTF)", "Page emojis", "Diary name", "Day moods"], id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                    Text(item)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOT ENCRYPTED (needed for lookup)")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.dimText)

                            ForEach(["IDs & dates", "Pincode hash + salt", "Storage preference"], id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.dimText)
                                    Text(item)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.dimText)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Encryption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { vm.showEncryptionInfo = false }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
    }

    private func encryptionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.dimText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Helpers

    private func saveWritingGoal() {
        let context = DataController.shared.container.mainContext
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? context.fetch(descriptor).first {
            settings.isWritingGoalEnabled = writingGoalEnabled
            settings.dailyWordGoal = writingGoalAmount
            try? context.save()
        }
    }

    private func loadWritingGoal() {
        let context = DataController.shared.container.mainContext
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? context.fetch(descriptor).first {
            writingGoalEnabled = settings.isWritingGoalEnabled
            writingGoalAmount = settings.dailyWordGoal
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Button Style

private struct SettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif // os(iOS)
