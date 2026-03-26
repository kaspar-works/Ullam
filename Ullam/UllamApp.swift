import SwiftUI
import SwiftData

@main
struct UllamApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let dataController = DataController.shared
    @State private var diaryManager: DiaryManager
    @State private var showPincodeOverlay: Bool = false
    @State private var hasCompletedOnboarding: Bool

    init() {
        let manager = DiaryManager(modelContext: DataController.shared.container.mainContext)
        _diaryManager = State(initialValue: manager)

        // Check if onboarding is completed (use UserDefaults so it survives DB resets)
        _hasCompletedOnboarding = State(initialValue: UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
                    .onAppear {
                        // Create default diary if needed (only after onboarding)
                        DataController.shared.createDefaultDiaryIfNeeded()

                        // Auto-open default diary if not protected
                        if !diaryManager.isUnlocked {
                            _ = diaryManager.openDefaultDiaryIfUnprotected()
                        }

                        // Seed sample data on first launch
                        SampleDataGenerator.seedIfNeeded(diaryManager: diaryManager)
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .onChange(of: hasCompletedOnboarding) { _, completed in
                        if completed {
                            // Save to UserDefaults (survives DB resets)
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                            // Also save in DB settings
                            let settings = dataController.getOrCreateSettings()
                            settings.hasCompletedOnboarding = true
                            try? dataController.container.mainContext.save()

                            // Create default diary
                            DataController.shared.createDefaultDiaryIfNeeded()

                            // Open default diary
                            _ = diaryManager.openDefaultDiaryIfUnprotected()
                        }
                    }
            }
        }
        .modelContainer(dataController.container)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock diary when app goes to background if it's protected
            if diaryManager.currentDiary?.isProtected == true {
                diaryManager.lockCurrentDiary()
            }
        case .inactive:
            break
        case .active:
            break
        @unknown default:
            break
        }
    }
}

struct RootView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    var body: some View {
        ZStack {
            if diaryManager.isUnlocked {
                MainTabView(diaryManager: diaryManager, showPincodeOverlay: $showPincodeOverlay)
            } else {
                // Show pincode entry if default diary is protected or no diary is open
                PincodeEntryView(diaryManager: diaryManager)
            }

            // Overlay for switching diaries
            if showPincodeOverlay {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showPincodeOverlay = false
                    }

                DirarySwitcherView(diaryManager: diaryManager, isPresented: $showPincodeOverlay)
                    .frame(maxWidth: 400, maxHeight: 600)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 20)
                    .padding(40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: diaryManager.isUnlocked)
        .animation(.easeInOut(duration: 0.2), value: showPincodeOverlay)
    }
}

// Diary switcher with visible diaries list + pincode entry
struct DirarySwitcherView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var isPresented: Bool

    @State private var visibleDiaries: [Diary] = []
    @State private var selectedDiary: Diary?
    @State private var enteredPincode: String = ""
    @State private var isUnlocking: Bool = false
    @State private var shake: Bool = false
    @State private var showPincodeSection: Bool = false
    @State private var showCreateDiary: Bool = false

    let minDigits = 4
    let maxDigits = 6

    var canSubmitPincode: Bool {
        enteredPincode.count >= minDigits && enteredPincode.count <= maxDigits
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Visible diaries list
                        if !visibleDiaries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Diaries")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(visibleDiaries) { diary in
                                    DiaryRowButton(
                                        diary: diary,
                                        isCurrentDiary: diary.id == diaryManager.currentDiary?.id,
                                        onTap: { selectDiary(diary) }
                                    )
                                }
                            }
                            .padding(.top, 8)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Create new diary button
                        NavigationLink {
                            DiaryCreationView(diaryManager: diaryManager)
                                .onDisappear {
                                    // Refresh diary list after creation
                                    visibleDiaries = diaryManager.getVisibleDiaries()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Create New Diary")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(.primary)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        Divider()
                            .padding(.vertical, 8)

                        // Pincode entry section
                        VStack(spacing: 16) {
                            Button {
                                withAnimation {
                                    showPincodeSection.toggle()
                                    if !showPincodeSection {
                                        enteredPincode = ""
                                        selectedDiary = nil
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "key")
                                    Text(selectedDiary != nil ? "Enter Pincode for \(selectedDiary?.name ?? "")" : "Enter Pincode")
                                    Spacer()
                                    Image(systemName: showPincodeSection ? "chevron.up" : "chevron.down")
                                }
                                .foregroundStyle(.primary)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)

                            if showPincodeSection {
                                VStack(spacing: 16) {
                                    // Pincode dots
                                    HStack(spacing: 10) {
                                        ForEach(0..<maxDigits, id: \.self) { index in
                                            Circle()
                                                .fill(index < enteredPincode.count ? Color.primary : Color.secondary.opacity(0.3))
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                    .modifier(ShakeEffect(shake: shake))

                                    Text("4-6 digits")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    // Numpad
                                    NumpadView(
                                        enteredValue: $enteredPincode,
                                        maxDigits: maxDigits,
                                        onComplete: nil
                                    )

                                    // Submit button
                                    Button {
                                        attemptUnlock()
                                    } label: {
                                        Text("Unlock")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(canSubmitPincode ? Color.accentColor : Color.secondary.opacity(0.3))
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canSubmitPincode || isUnlocking)
                                    .padding(.horizontal)
                                }
                                .padding(.bottom, 16)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Switch Diary")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .disabled(isUnlocking)
        .overlay {
            if isUnlocking {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            visibleDiaries = diaryManager.getVisibleDiaries()
        }
    }

    private func selectDiary(_ diary: Diary) {
        if diary.isProtected {
            // Show pincode entry for this diary
            selectedDiary = diary
            showPincodeSection = true
            enteredPincode = ""
        } else {
            // Open unprotected diary directly
            diaryManager.openDiary(diary)
            isPresented = false
        }
    }

    private func attemptUnlock() {
        guard canSubmitPincode else { return }

        isUnlocking = true

        Task {
            var success = false

            if let diary = selectedDiary {
                // Try to unlock specific diary
                success = await diaryManager.unlockSpecificDiary(diary, with: enteredPincode)
            } else {
                // Try to unlock any diary with this pincode
                success = await diaryManager.unlockDiary(with: enteredPincode)
            }

            isUnlocking = false

            if success {
                isPresented = false
            } else {
                showErrorFeedback()
            }

            enteredPincode = ""
        }
    }

    private func showErrorFeedback() {
        withAnimation(.default) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
        }
    }
}

struct DiaryRowButton: View {
    let diary: Diary
    let isCurrentDiary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: diary.isProtected ? "lock.fill" : "book.closed")
                    .foregroundStyle(diary.isProtected ? .orange : .secondary)

                Text(diary.name)
                    .foregroundStyle(.primary)

                Spacer()

                if isCurrentDiary {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(isCurrentDiary ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
