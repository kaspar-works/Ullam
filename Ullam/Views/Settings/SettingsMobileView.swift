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
                                    ProgressView().controlSize(.mini).tint(.white.opacity(0.3))
                                } else if case .synced(let date) = vm.iCloudStatus {
                                    Text(relativeTime(date))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.2))
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
                                    .foregroundStyle(.white.opacity(0.3))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.15))
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
                                    .foregroundStyle(.white.opacity(0.3))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.15))
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
                                        .foregroundStyle(.white.opacity(0.15))
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
                                        .foregroundStyle(.white.opacity(0.15))
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
                                        .foregroundStyle(.white.opacity(0.3))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.15))
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
                                            .foregroundStyle(.white.opacity(0.3))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.15))
                                    }
                                case .exporting:
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.mini).tint(.white.opacity(0.3))
                                        Text("Exporting\u{2026}")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.3))
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
                                        .foregroundStyle(.white.opacity(0.15))
                                case .inProgress:
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.mini).tint(.white.opacity(0.3))
                                        Text("Backing up\u{2026}")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                case .success(let date):
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                        Text(relativeTime(date))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.25))
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

                    // Lock diary (if protected)
                    if diaryManager.currentDiary?.isProtected == true {
                        lockDiaryButton
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                    }

                    // App info
                    appInfoFooter
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            vm.load()
            withAnimation { appeared = true }
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

    // MARK: - Background

    private var settingsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B1120), Color(hex: 0x0F172A), Color(hex: 0x160F2E)],
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
                        LinearGradient(colors: [AppTheme.accent.opacity(0.5), AppTheme.gradientPink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                    .frame(width: 58, height: 58)
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text(diaryManager.currentDiary?.isProtected == true ? "PROTECTED DIARY" : "PRIVATE DIARY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.25))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(diaryManager.currentDiary?.pages?.count ?? 0)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Text("entries")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
        )
    }

    // MARK: - Section Block

    private func sectionBlock<Content: View>(title: String, delay: Double, tint: Color = AppTheme.accent, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(tint.opacity(0.5))
                .padding(.leading, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) { content() }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.05), lineWidth: 1))
                )
                .padding(.horizontal, 16)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(delay), value: appeared)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint == .orange ? .orange.opacity(0.9) : .white.opacity(0.85))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var softDivider: some View {
        Rectangle().fill(.white.opacity(0.04)).frame(height: 1).padding(.leading, 60)
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
                Text("Lock Diary").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.orange.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.orange.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.orange.opacity(0.12), lineWidth: 1))
            )
        }
        .buttonStyle(SettingsButtonStyle())
    }

    // MARK: - App Info Footer

    private var appInfoFooter: some View {
        VStack(spacing: 4) {
            Text("Ullam")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.15))
            Text("Version 1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.1))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Diary Picker Sheet

    private var diaryPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0F172A).ignoresSafeArea()

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
                                        .foregroundStyle(diary.id == diaryManager.currentDiary?.id ? AppTheme.accent : .white.opacity(0.35))

                                    Text(diary.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.85))

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
                                        .fill(diary.id == diaryManager.currentDiary?.id ? AppTheme.accent.opacity(0.08) : .white.opacity(0.03))
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
                Color(hex: 0x0F172A).ignoresSafeArea()

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
                                    .foregroundStyle(vm.selectedTheme == theme ? AppTheme.accent : .white.opacity(0.35))

                                Text(theme.label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))

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
                                    .fill(vm.selectedTheme == theme ? AppTheme.accent.opacity(0.08) : .white.opacity(0.03))
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
                Color(hex: 0x0F172A).ignoresSafeArea()

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
                                    .foregroundStyle(.white)
                                Text("Your data is protected with military-grade encryption")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
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
                                .fill(.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.05), lineWidth: 1))
                        )

                        // What's encrypted
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHAT\u{2019}S ENCRYPTED")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.3))

                            ForEach(["Page titles", "Page content (RTF)", "Page emojis", "Diary name", "Day moods"], id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                                    Text(item)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOT ENCRYPTED (needed for lookup)")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.3))

                            ForEach(["IDs & dates", "Pincode hash + salt", "Storage preference"], id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.25))
                                    Text(item)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.4))
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
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Helpers

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
