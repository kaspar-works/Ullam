#if os(iOS)
import SwiftUI
import SwiftData

struct PastSelfChatView: View {
    @Bindable var diaryManager: DiaryManager

    @State private var messages: [ConversationMessage] = []
    @State private var currentInput: String = ""
    @State private var isSearching: Bool = false

    private let service = PastSelfService()

    private let suggestedQuestions = [
        "How was I feeling last month?",
        "What was I grateful for?",
        "What worried me recently?",
        "What made me happy?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }

                        if isSearching {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(AppTheme.accent)
                                Text("Searching your memories...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            if messages.isEmpty {
                suggestedQuestionsView
            }

            inputBar
        }
        .background(AppTheme.bg)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "moon.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Past Self")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("YOUR DIARY REMEMBERS")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.dimText)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "moon.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.accent.opacity(0.4))

            Text("Ask your past self anything.\nThey remember everything you've written.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: ConversationMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 48)
            } else {
                // Past Self avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.top, 2)
            }

            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if message.isUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.25))
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.3))
                        }
                    }
                )

            if !message.isUser {
                Spacer(minLength: 48)
            }
        }
    }

    // MARK: - Suggested Questions

    private var suggestedQuestionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button {
                        sendMessage(question)
                    } label: {
                        Text(question)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial.opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your past self...", text: $currentInput)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppTheme.subtle)
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
                        )
                )
                .onSubmit {
                    sendMessage(currentInput)
                }

            Button {
                sendMessage(currentInput)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.mutedText
                            : AppTheme.accent
                    )
            }
            .disabled(currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.bg)
    }

    // MARK: - Send

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ConversationMessage(text: trimmed, isUser: true)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(userMessage)
        }
        currentInput = ""
        isSearching = true

        Task {
            let entries = await service.findRelevantEntries(query: trimmed, diaryManager: diaryManager)

            let mapped = entries.map { (title: $0.title, body: $0.body, date: $0.date) }
            let responseText = service.generateResponse(query: trimmed, entries: mapped)

            let relatedDate = entries.first?.date
            let responseMessage = ConversationMessage(
                text: responseText,
                isUser: false,
                relatedEntryDate: relatedDate
            )

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isSearching = false
                messages.append(responseMessage)
            }
        }
    }
}

#Preview {
    PastSelfChatView(
        diaryManager: DiaryManager(modelContext: DataController.shared.container.mainContext)
    )
}
#endif
