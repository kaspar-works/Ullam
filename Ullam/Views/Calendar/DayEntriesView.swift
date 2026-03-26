import SwiftUI
import SwiftData

struct DayEntriesView: View {
    @Bindable var diaryManager: DiaryManager
    let date: Date
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [(title: String, body: String, emojis: [String], createdAt: Date)] = []
    @State private var isLoading = true

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Date header
                Text(formattedDate)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.dimText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.dimText)
                        Text("No entries for this day")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 8) {
                            // Time + emojis
                            HStack(spacing: 6) {
                                Text(formatTime(entry.createdAt))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.accent)
                                ForEach(entry.emojis, id: \.self) { e in
                                    Text(e).font(.system(size: 12))
                                }
                                Spacer()
                            }

                            // Title
                            Text(entry.title.isEmpty ? "Untitled Entry" : entry.title)
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundStyle(.black.opacity(0.85))

                            // Body preview
                            if !entry.body.isEmpty {
                                Text(String(entry.body.prefix(200)))
                                    .font(.system(size: 14))
                                    .foregroundStyle(.black.opacity(0.5))
                                    .lineSpacing(4)
                                    .lineLimit(5)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.cardBg)
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(AppTheme.bg)
        .navigationTitle("Day Entries")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task { await loadEntries() }
    }

    private func loadEntries() async {
        let pages = diaryManager.getPages(for: date)
        var results: [(title: String, body: String, emojis: [String], createdAt: Date)] = []

        for page in pages {
            if let decrypted = await diaryManager.decryptPage(page) {
                let plainText: String
                if let data = decrypted.content,
                   let attr = try? NSAttributedString(
                       data: data,
                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                       documentAttributes: nil
                   ) {
                    plainText = attr.string
                } else {
                    plainText = ""
                }
                results.append((title: decrypted.title, body: plainText, emojis: decrypted.emojis, createdAt: page.createdAt))
            }
        }

        entries = results
        isLoading = false
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
