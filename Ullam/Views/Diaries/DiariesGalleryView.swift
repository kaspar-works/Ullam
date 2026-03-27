import SwiftUI
import SwiftData

struct DiariesGalleryView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var allDiaries: [Diary] = []
    @State private var showCreateDiary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                // Current diary card (featured)
                if let current = diaryManager.currentDiary {
                    currentDiaryCard(current)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                }

                // Other diaries
                if !otherDiaries.isEmpty {
                    Text("OTHER DIARIES")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.dimText)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(otherDiaries) { diary in
                            diaryCard(diary)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }

                // Hidden diaries hint
                Button { showPincodeOverlay = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text("Enter pincode to access hidden diaries")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear { refreshDiaries() }
        .sheet(isPresented: $showCreateDiary) {
            NavigationStack {
                DiaryCreationView(diaryManager: diaryManager)
            }
            .frame(minWidth: 400, minHeight: 500)
            .onDisappear { refreshDiaries() }
        }
    }

    private var otherDiaries: [Diary] {
        allDiaries.filter { $0.id != diaryManager.currentDiary?.id && $0.isVisibleOnSwitch && !$0.isProtected }
    }

    private func refreshDiaries() {
        allDiaries = DataController.shared.fetchAllDiaries()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nocturnal Archives")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("A curated sanctuary for your innermost reflections.\nEach journal holds a unique frequency of your life's journey.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.dimText)
                    .lineSpacing(4)
            }

            Spacer()

            Button { showCreateDiary = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Create New Diary")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Current Diary Card

    private func currentDiaryCard(_ diary: Diary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CURRENT FOCUS")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(AppTheme.dimText)

            Text(diary.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            if diary.isProtected {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Encrypted")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(AppTheme.indigo)
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\((diary.pages?.count ?? 0))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("ENTRIES")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.dimText)
                }

                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(diary.storagePreference == .iCloud ? "iCloud" : "Local")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("STORAGE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.dimText)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.sidebarBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    // MARK: - Diary Card

    private func diaryCard(_ diary: Diary) -> some View {
        Button {
            diaryManager.openDiary(diary)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.sidebarBg, AppTheme.bg],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)

                    Image(systemName: "text.book.closed")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.08))
                }

                Text(diary.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("\((diary.pages?.count ?? 0)) entries · \(diary.storagePreference == .iCloud ? "iCloud" : "Local")")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        DiariesGalleryView(
            diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext),
            showPincodeOverlay: .constant(false)
        )
    }
}
