import SwiftUI
import SwiftData
import Speech
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import AVFoundation

struct PageEditorMobileView: View {
    @Bindable var diaryManager: DiaryManager
    let page: Page
    let date: Date

    @State private var title: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var selectedEmojis: [String] = []
    @State private var formatAction: FormatAction?
    @State private var isLoaded: Bool = false
    @State private var showingEmojiPicker: Bool = false
    @State private var showingImagePicker: Bool = false
    @State private var isListening: Bool = false

    private let maxEmojis = 3

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy · h:mm a"
        return f.string(from: page.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            TextField("Untitled Entry", text: $title)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(.white.opacity(title.isEmpty ? 0.25 : 0.9))
                .textFieldStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .onChange(of: title) { _, _ in saveNow() }

            // Date
            Text(formattedDate.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppTheme.dimText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 10)

            // Formatting toolbar
            formattingBar

            // Editor card
            #if canImport(UIKit)
            RichTextEditor(
                attributedText: $attributedContent,
                placeholder: "What's on your mind?",
                focusOnAppear: true,
                formatAction: $formatAction,
                onTextChange: { _ in saveNow() }
            )
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            #endif
        }
        .background(AppTheme.bg)
        .task { await loadPage() }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: .constant(nil)) { emoji in
                if selectedEmojis.count < maxEmojis {
                    selectedEmojis.append(emoji)
                    saveNow()
                }
                showingEmojiPicker = false
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Formatting Bar

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Emojis
                ForEach(Array(selectedEmojis.enumerated()), id: \.offset) { index, emoji in
                    Button {
                        selectedEmojis.remove(at: index)
                        saveNow()
                    } label: {
                        Text(emoji).font(.system(size: 16)).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                if selectedEmojis.count < maxEmojis {
                    fmtBtn(icon: "face.smiling") { showingEmojiPicker = true }
                }

                fmtSep()

                fmtBtn(icon: "bold") { formatAction = .bold }
                fmtBtn(icon: "italic") { formatAction = .italic }
                fmtBtn(icon: "underline") { formatAction = .underline }
                fmtBtn(icon: "strikethrough") { formatAction = .strikethrough }

                fmtSep()

                fmtBtn(icon: "highlighter") { formatAction = .highlight }
                fmtBtn(icon: "paintbrush.pointed") { /* color - future */ }

                fmtSep()

                fmtBtn(icon: "text.quote") { formatAction = .quote }
                FormatButton(label: "H1", isActive: false) { formatAction = .heading }
                FormatButton(label: "H2", isActive: false) { formatAction = .subheading }

                fmtSep()

                fmtBtn(icon: "list.bullet") { formatAction = .bulletList }
                fmtBtn(icon: "list.number") { formatAction = .numberedList }
                fmtBtn(icon: "minus") { formatAction = .separator }

                fmtSep()

                fmtBtn(icon: "photo") { showingImagePicker = true }

                // Voice-to-text
                Button { toggleVoice() } label: {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isListening ? .red : AppTheme.mutedText)
                        .frame(width: 28, height: 28)
                        .background(isListening ? Color.red.opacity(0.15) : AppTheme.subtle)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(AppTheme.sidebarBg)
    }

    private func fmtBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func fmtSep() -> some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }

    // MARK: - Voice

    @State private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    private func toggleVoice() {
        if isListening { stopListening() } else { startListening() }
    }

    private func startListening() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                beginRecording()
            }
        }
    }

    private func beginRecording() {
        recognitionTask?.cancel()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch { return }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    let current = self.attributedContent.string
                    let sep = current.isEmpty ? "" : " "
                    let font = UIFont.preferredFont(forTextStyle: .body)
                    self.attributedContent = NSAttributedString(string: current + sep + text, attributes: [.font: font, .foregroundColor: UIColor.black.withAlphaComponent(0.8)])
                    self.saveNow()
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self.stopListening() }
            }
        }
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
    }

    // MARK: - Data

    private func loadPage() async {
        guard !isLoaded else { return }
        if let decrypted = await diaryManager.decryptPage(page) {
            title = decrypted.title
            selectedEmojis = decrypted.emojis
            if let data = decrypted.content,
               let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                attributedContent = attr
            }
        }
        isLoaded = true
    }

    private func saveNow() {
        Task {
            var contentData: Data?
            if attributedContent.length > 0 {
                contentData = try? attributedContent.data(from: NSRange(location: 0, length: attributedContent.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            }
            await diaryManager.savePage(page, title: title, subtitle: nil, content: contentData, emojis: selectedEmojis)
        }
    }
}

#endif // canImport(UIKit)
