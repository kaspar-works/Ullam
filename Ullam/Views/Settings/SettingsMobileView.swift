#if os(iOS)
import SwiftUI
import SwiftData
import UIKit

struct SettingsMobileView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var iCloudSync: Bool = false
    @State private var biometricEnabled: Bool = false
    @State private var showPincodeSetup: Bool = false
    @State private var pincodeSetupMode: PincodeSetupMode = .setup
    @State private var isExporting: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var exportedPDFURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Avatar
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Text(String((diaryManager.currentDiary?.name ?? "U").prefix(1)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text(diaryManager.currentDiary?.name ?? "Ullam User")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Text(diaryManager.currentDiary?.isProtected == true ? "PROTECTED DIARY" : "PRIVATE DIARY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.dimText)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)

                // General
                sectionLabel("GENERAL")

                settingsGroup {
                    settingsRow(icon: "icloud.fill", label: "iCloud Sync") {
                        Toggle("", isOn: $iCloudSync)
                            .toggleStyle(.switch)
                            .tint(AppTheme.accent)
                            .labelsHidden()
                            .onChange(of: iCloudSync) { _, newValue in
                                DataController.shared.iCloudEnabled = newValue
                                if let diary = diaryManager.currentDiary {
                                    diary.storagePreference = newValue ? .iCloud : .local
                                }
                                DataController.shared.save()
                            }
                    }

                    settingsDivider

                    settingsRow(icon: "text.book.closed.fill", label: "Default Diary") {
                        Text(diaryManager.currentDiary?.name ?? "Me & Me")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.dimText)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.2))
                    }

                    settingsDivider

                    settingsRow(icon: "moon.fill", label: "Theme Mode") {
                        Text("Dark")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.dimText)
                    }
                }

                // Privacy & Security
                sectionLabel("PRIVACY & SECURITY")

                settingsGroup {
                    settingsRow(icon: "faceid", label: "Face ID / Touch ID") {
                        Toggle("", isOn: $biometricEnabled)
                            .toggleStyle(.switch)
                            .tint(AppTheme.accent)
                            .labelsHidden()
                            .onChange(of: biometricEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "biometricEnabled")
                            }
                    }

                    settingsDivider

                    if diaryManager.currentDiary?.isProtected == true {
                        Button {
                            pincodeSetupMode = .change
                            showPincodeSetup = true
                        } label: {
                            settingsRow(icon: "lock.fill", label: "Change Pincode") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                        }
                        .buttonStyle(.plain)

                        settingsDivider

                        Button {
                            pincodeSetupMode = .remove
                            showPincodeSetup = true
                        } label: {
                            settingsRow(icon: "lock.open", label: "Remove Pincode", tint: .orange) {
                                EmptyView()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            pincodeSetupMode = .setup
                            showPincodeSetup = true
                        } label: {
                            settingsRow(icon: "lock.fill", label: "Set Up Pincode") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    settingsDivider

                    settingsRow(icon: "shield.fill", label: "Encryption Info") {
                        Text("AES-256")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.dimText)
                    }
                }

                // Data
                sectionLabel("DATA")

                settingsGroup {
                    Button {
                        isExporting = true
                        Task {
                            await exportDiaryAsPDF()
                            isExporting = false
                        }
                    } label: {
                        settingsRow(icon: "square.and.arrow.up", label: "Export Diary") {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("PDF")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.dimText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting)

                    settingsDivider

                    settingsRow(icon: "arrow.clockwise", label: "Backup") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }

                // Lock diary
                if diaryManager.currentDiary?.isProtected == true {
                    sectionLabel("SECURITY")

                    settingsGroup {
                        Button {
                            diaryManager.lockCurrentDiary()
                            _ = diaryManager.openDefaultDiaryIfUnprotected()
                        } label: {
                            settingsRow(icon: "lock.fill", label: "Lock Diary", tint: .orange) {
                                EmptyView()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(AppTheme.bg)
        .navigationTitle("Settings")
        .onAppear {
            iCloudSync = DataController.shared.iCloudEnabled
            biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        }
        .sheet(isPresented: $showPincodeSetup) {
            NavigationStack {
                PincodeSetupView(diaryManager: diaryManager, mode: pincodeSetupMode)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedPDFURL {
                ShareSheetView(items: [url])
            }
        }
    }

    // MARK: - Export

    private func exportDiaryAsPDF() async {
        let diaryName = diaryManager.currentDiary?.name ?? "Diary"
        let pageData = await diaryManager.decryptAllPagesForExport()

        guard !pageData.isEmpty,
              let pdfData = PDFExporter.exportPages(pageData, diaryName: diaryName) else {
            return
        }

        // Write to a temporary file so UIActivityViewController can share it
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(diaryName).pdf")
        do {
            try pdfData.write(to: tempURL)
            exportedPDFURL = tempURL
            showShareSheet = true
        } catch {
            // Silently fail; could surface an alert in a future iteration
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(AppTheme.dimText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.subtle))
    }

    private var settingsDivider: some View {
        Divider().opacity(0.08).padding(.leading, 44)
    }

    private func settingsRow<Trailing: View>(icon: String, label: String, tint: Color = AppTheme.accent, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(tint == .orange ? .orange : .white)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Share Sheet

/// Wraps UIActivityViewController for use as a SwiftUI sheet.
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif // os(iOS)
