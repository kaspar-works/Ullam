#if os(iOS)
import SwiftUI
import SwiftData

struct DiariesMobileView: View {
    @Bindable var diaryManager: DiaryManager
    @Binding var showPincodeOverlay: Bool

    @State private var allDiaries: [Diary] = []
    @State private var showCreateDiary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Your\nSanctuaries")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Text("Private spaces for your thoughts.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.dimText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // Current diary (featured)
                if let current = diaryManager.currentDiary {
                    currentDiaryCard(current)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                // Other visible diaries
                ForEach(otherDiaries) { diary in
                    Button {
                        diaryManager.openDiary(diary)
                        refreshDiaries()
                    } label: {
                        diaryRow(diary: diary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                // Hidden diary access
                Button { showPincodeOverlay = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text("Enter pincode for hidden diaries")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.accent.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Create new diary
                Button { showCreateDiary = true } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("Create New Diary")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(AppTheme.bg)
        .onAppear { refreshDiaries() }
        .sheet(isPresented: $showCreateDiary) {
            NavigationStack {
                DiaryCreationView(diaryManager: diaryManager)
            }
            .onDisappear { refreshDiaries() }
        }
    }

    private var otherDiaries: [Diary] {
        allDiaries.filter { $0.id != diaryManager.currentDiary?.id && $0.isVisibleOnSwitch && !$0.isProtected }
    }

    private func refreshDiaries() {
        allDiaries = DataController.shared.fetchAllDiaries()
    }

    // MARK: - Cards

    private func currentDiaryCard(_ diary: Diary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: diary.isProtected ? "lock.fill" : "text.book.closed.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT DIARY")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.accent)
                    Text(diary.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                Label("\(diary.pages.count) entries", systemImage: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)

                Label(diary.storagePreference == .iCloud ? "iCloud" : "Local", systemImage: diary.storagePreference == .iCloud ? "icloud" : "iphone")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
            }

            if diary.isProtected {
                Label("Encrypted", systemImage: "lock.shield")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.indigo)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.sidebarBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func diaryRow(diary: Diary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.subtle)
                    .frame(width: 36, height: 36)
                Image(systemName: diary.isProtected ? "lock.fill" : "text.book.closed")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.mutedText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(diary.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(diary.pages.count) entries")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.subtle)
        )
    }
}
#endif // os(iOS)
