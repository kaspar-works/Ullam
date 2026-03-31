import SwiftUI
import SwiftData

struct DiaryCreationView: View {
    @Bindable var diaryManager: DiaryManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var useProtection: Bool = false
    @State private var isVisibleOnSwitch: Bool = true
    @State private var storagePreference: StoragePreference = .iCloud
    @State private var pincode: String = ""
    @State private var confirmPincode: String = ""
    @State private var isCreating: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var creationComplete: Bool = false

    private var isValid: Bool {
        !name.isEmpty && (!useProtection || (pincode.count >= 4 && pincode == confirmPincode))
    }

    var body: some View {
        Form {
            Section {
                TextField("Diary Name", text: $name)
            } header: {
                Text("Name")
            }

            Section {
                Toggle("Protect with Pincode", isOn: $useProtection)

                if useProtection {
                    SecureField("Pincode (4-6 digits)", text: $pincode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: pincode) { _, newValue in
                            pincode = String(newValue.filter { $0.isNumber }.prefix(6))
                        }

                    SecureField("Confirm Pincode", text: $confirmPincode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: confirmPincode) { _, newValue in
                            confirmPincode = String(newValue.filter { $0.isNumber }.prefix(6))
                        }

                    if !pincode.isEmpty && !confirmPincode.isEmpty && pincode != confirmPincode {
                        Text("Pincodes don't match")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Security")
            } footer: {
                if useProtection {
                    Text("Your diary will be encrypted. You'll need this pincode to access it. There is no way to recover a forgotten pincode.")
                }
            }

            Section {
                Toggle("Show in Diary List", isOn: $isVisibleOnSwitch)
            } header: {
                Text("Visibility")
            } footer: {
                if isVisibleOnSwitch {
                    Text("This diary will appear in the switch list. If protected, you'll need to enter the pincode to access it.")
                } else {
                    Text("This diary will be hidden. You can only access it by entering its pincode directly.")
                }
            }

            Section {
                Picker("Storage", selection: $storagePreference) {
                    Text("Local Only").tag(StoragePreference.local)
                    Text("iCloud").tag(StoragePreference.iCloud)
                }
            } header: {
                Text("Storage")
            } footer: {
                if storagePreference == .iCloud {
                    Text("This diary will sync across your devices using iCloud.")
                } else {
                    Text("This diary will only be stored on this device.")
                }
            }

            // Create button as a section
            Section {
                Button {
                    createDiary()
                } label: {
                    HStack {
                        Spacer()
                        if isCreating {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Create Diary")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(!isValid || isCreating)
            }
        }
        .navigationTitle("New Diary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Diary Created", isPresented: $creationComplete) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your new diary '\(name)' has been created.")
        }
    }

    private func createDiary() {
        guard isValid else { return }

        isCreating = true

        Task {
            let _ = await diaryManager.createDiary(
                name: name,
                pincode: useProtection ? pincode : nil,
                isVisibleOnSwitch: isVisibleOnSwitch,
                storagePreference: storagePreference
            )

            isCreating = false
            creationComplete = true
        }
    }
}

#Preview {
    NavigationStack {
        DiaryCreationView(diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext))
    }
}
