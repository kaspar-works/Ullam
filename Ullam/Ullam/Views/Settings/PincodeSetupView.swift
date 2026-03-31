import SwiftUI
import SwiftData

enum PincodeSetupMode {
    case setup      // First time setting pincode
    case change     // Change existing pincode
    case remove     // Remove pincode
}

struct PincodeSetupView: View {
    @Bindable var diaryManager: DiaryManager
    @Environment(\.dismiss) private var dismiss

    let mode: PincodeSetupMode

    @State private var currentPincode: String = ""
    @State private var newPincode: String = ""
    @State private var confirmPincode: String = ""
    @State private var isProcessing: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false

    private var isValid: Bool {
        switch mode {
        case .setup:
            return newPincode.count >= 4 && newPincode.count <= 6 && newPincode == confirmPincode
        case .change:
            return currentPincode.count >= 4 && newPincode.count >= 4 && newPincode.count <= 6 && newPincode == confirmPincode
        case .remove:
            return currentPincode.count >= 4
        }
    }

    var body: some View {
        Form {
            // Current diary info
            Section {
                HStack {
                    Image(systemName: diaryManager.currentDiary?.isProtected == true ? "lock.fill" : "lock.open")
                        .foregroundStyle(AppTheme.accent)
                    Text(diaryManager.currentDiary?.name ?? "Unknown")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    if diaryManager.currentDiary?.isProtected == true {
                        Text("Protected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.indigo.opacity(0.15)))
                    } else {
                        Text("Unprotected")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Diary")
            }

            // Current pincode (for change/remove)
            if mode == .change || mode == .remove {
                Section {
                    SecureField("Current Pincode", text: $currentPincode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: currentPincode) { _, val in
                            currentPincode = String(val.filter { $0.isNumber }.prefix(6))
                        }
                } header: {
                    Text("Verify Current Pincode")
                } footer: {
                    Text("Enter your current 4-6 digit pincode to continue.")
                }
            }

            // New pincode (for setup/change)
            if mode == .setup || mode == .change {
                Section {
                    SecureField("New Pincode (4-6 digits)", text: $newPincode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: newPincode) { _, val in
                            newPincode = String(val.filter { $0.isNumber }.prefix(6))
                        }

                    SecureField("Confirm New Pincode", text: $confirmPincode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: confirmPincode) { _, val in
                            confirmPincode = String(val.filter { $0.isNumber }.prefix(6))
                        }

                    if !newPincode.isEmpty && !confirmPincode.isEmpty && newPincode != confirmPincode {
                        Label("Pincodes don't match", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                } header: {
                    Text("New Pincode")
                } footer: {
                    Text("Your diary will be encrypted with AES-256. All entries, titles, and emojis will be protected. There is no way to recover a forgotten pincode.")
                }
            }

            // Remove warning
            if mode == .remove {
                Section {
                    Label("All entries will be decrypted and stored in plaintext.", systemImage: "exclamationmark.shield")
                        .foregroundStyle(.orange)
                        .font(.callout)
                } header: {
                    Text("Warning")
                }
            }

            // Action button
            Section {
                Button {
                    performAction()
                } label: {
                    HStack {
                        Spacer()
                        if isProcessing {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(actionButtonLabel)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(!isValid || isProcessing)
            }
        }
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text(successMessage)
        }
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        switch mode {
        case .setup: return "Set Up Pincode"
        case .change: return "Change Pincode"
        case .remove: return "Remove Pincode"
        }
    }

    private var actionButtonLabel: String {
        switch mode {
        case .setup: return "Enable Protection"
        case .change: return "Change Pincode"
        case .remove: return "Remove Protection"
        }
    }

    private var successMessage: String {
        switch mode {
        case .setup: return "Your diary is now protected with a pincode. All entries have been encrypted."
        case .change: return "Your pincode has been changed successfully."
        case .remove: return "Pincode protection has been removed. Your entries are now stored in plaintext."
        }
    }

    private func performAction() {
        isProcessing = true

        Task {
            var success = false

            switch mode {
            case .setup:
                success = await diaryManager.setupPincode(newPincode)

            case .change:
                success = await diaryManager.changePincode(oldPincode: currentPincode, newPincode: newPincode)

            case .remove:
                // Verify current pincode first
                guard let diary = diaryManager.currentDiary,
                      let salt = diary.encryptionSalt,
                      let hash = diary.pincodeHash else {
                    errorMessage = "Diary is not protected."
                    showError = true
                    isProcessing = false
                    return
                }

                let verified = await EncryptionManager.shared.verifyPincode(currentPincode, againstHash: hash, salt: salt)
                if !verified {
                    errorMessage = "Incorrect pincode."
                    showError = true
                    isProcessing = false
                    return
                }

                success = await diaryManager.removePincode()
            }

            isProcessing = false

            if success {
                showSuccess = true
            } else {
                errorMessage = mode == .change ? "Incorrect current pincode." : "Operation failed. Please try again."
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PincodeSetupView(
            diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext),
            mode: .setup
        )
    }
}
