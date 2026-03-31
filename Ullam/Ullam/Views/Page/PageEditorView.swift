import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers
import Speech
import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Image Attachment Model

struct ImageAttachment: Identifiable {
    let id = UUID()
    #if canImport(UIKit)
    let image: UIImage
    #else
    let image: NSImage
    #endif
    let data: Data
}

struct PageEditorView: View {
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
    @State private var showingColorPicker: Bool = false
    @State private var selectedTextColor: Color = .black
    @State private var isFocusMode: Bool = false
    @State private var showSaveIndicator: Bool = false
    @State private var wordCount: Int = 0
    @Binding var attachedImages: [ImageAttachment]

    private let maxEmojis = 3
    private let maxImages = 5

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: page.createdAt)
    }

    var body: some View {
        ZStack {
            // Deep background
            ZStack {
                AppTheme.bg
                RadialGradient(
                    colors: [AppTheme.accent.opacity(0.04), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 500
                )
                RadialGradient(
                    colors: [AppTheme.gradientPink.opacity(0.02), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 400
                )
            }

            VStack(spacing: 0) {
                // Title
                HStack(alignment: .center) {
                    TextField("Give your thoughts a title\u{2026}", text: $title)
                        .font(.custom("NewYork-Bold", size: 32, relativeTo: .largeTitle))
                        .foregroundStyle(title.isEmpty ? AppTheme.dimText : AppTheme.primaryText)
                        .textFieldStyle(.plain)

                    Spacer()

                    if showSaveIndicator {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Saved")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.accent.opacity(0.7))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else if wordCount > 0 {
                        Text("\(wordCount) words")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.dimText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .onChange(of: title) { _, _ in saveNow() }

                if !isFocusMode {
                    // Metadata row
                    metadataRow
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    // Formatting toolbar
                    formattingBar
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Editor
                VStack(spacing: 0) {
                    RichTextEditor(
                        attributedText: $attributedContent,
                        placeholder: "What\u{2019}s on your mind?",
                        focusOnAppear: true,
                        formatAction: $formatAction,
                        onTextChange: { newText in
                            saveNow()
                            let words = newText.string.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                            wordCount = words.count
                        }
                    )
                }
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, isFocusMode ? 8 : 16)
                .padding(.bottom, 8)
            }

            // Floating Focus exit
            if isFocusMode {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isFocusMode = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Exit Focus")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.sage)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(AppTheme.sidebarBg.opacity(0.85))
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.subtle, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isFocusMode)
        .animation(.easeInOut(duration: 0.3), value: showSaveIndicator)
        .task { await loadPage() }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: .constant(nil)) { emoji in
                if selectedEmojis.count < maxEmojis {
                    selectedEmojis.append(emoji)
                    saveNow()
                }
                showingEmojiPicker = false
            }
            #if os(iOS)
            .presentationDetents([.medium])
            #endif
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImageImport(result)
        }
        #if os(macOS)
        .background {
            VStack {
                Button("") { formatAction = .bold }
                    .keyboardShortcut("b", modifiers: .command)
                    .frame(width: 0, height: 0).opacity(0)
                Button("") { formatAction = .italic }
                    .keyboardShortcut("i", modifiers: .command)
                    .frame(width: 0, height: 0).opacity(0)
                Button("") { formatAction = .underline }
                    .keyboardShortcut("u", modifiers: .command)
                    .frame(width: 0, height: 0).opacity(0)
                Button("") { formatAction = .highlight }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                    .frame(width: 0, height: 0).opacity(0)
            }
            .allowsHitTesting(false)
        }
        #endif
    }

    // MARK: - Image Import

    private func handleImageImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard attachedImages.count < maxImages else { break }
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                #if canImport(UIKit)
                if let image = UIImage(data: data) {
                    attachedImages.append(ImageAttachment(image: image, data: data))
                }
                #else
                if let image = NSImage(data: data) {
                    attachedImages.append(ImageAttachment(image: image, data: data))
                }
                #endif
            }
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text(formattedDate)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppTheme.dimText)

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text(formattedTime)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppTheme.dimText)

            HStack(spacing: 5) {
                Image(systemName: "book.closed")
                    .font(.system(size: 11))
                Text(diaryManager.currentDiary?.name ?? "Diary")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppTheme.dimText)

            Spacer()

            // Emoji tags
            if !selectedEmojis.isEmpty {
                HStack(spacing: 4) {
                    ForEach(selectedEmojis, id: \.self) { emoji in
                        Text(emoji).font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppTheme.subtle)
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.subtle, lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Formatting Bar

    private func barSep() -> some View {
        Rectangle()
            .fill(AppTheme.subtle)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Emoji section
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
                    FormatButton(icon: "face.smiling", isActive: false) { showingEmojiPicker = true }
                }

                barSep()

                FormatButton(icon: "bold", isActive: false) { formatAction = .bold }
                FormatButton(icon: "italic", isActive: false) { formatAction = .italic }
                FormatButton(icon: "underline", isActive: false) { formatAction = .underline }
                FormatButton(icon: "strikethrough", isActive: false) { formatAction = .strikethrough }

                barSep()

                FormatButton(icon: "highlighter", isActive: false) { formatAction = .highlight }

                barSep()

                FormatButton(icon: "text.quote", isActive: false) { formatAction = .quote }
                FormatButton(label: "H1", isActive: false) { formatAction = .heading }
                FormatButton(label: "H2", isActive: false) { formatAction = .subheading }
                FormatButton(label: "T", isActive: false) { formatAction = .body }

                barSep()

                FormatButton(icon: "list.bullet", isActive: false) { formatAction = .bulletList }
                FormatButton(icon: "list.number", isActive: false) { formatAction = .numberedList }

                barSep()

                FormatButton(icon: "minus", isActive: false) { formatAction = .separator }

                barSep()

                // Color picker
                Button { showingColorPicker = true } label: {
                    ZStack {
                        Image(systemName: "paintbrush.pointed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedText)
                        Circle()
                            .fill(selectedTextColor)
                            .frame(width: 6, height: 6)
                            .offset(x: 7, y: 7)
                    }
                    .frame(width: 30, height: 30)
                    .background(AppTheme.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingColorPicker) {
                    textColorPalette
                }

                barSep()

                FormatButton(icon: "photo", isActive: false) { showingImagePicker = true }

                barSep()

                // Voice
                Button { toggleVoiceInput() } label: {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isListening ? .red : AppTheme.mutedText)
                        .frame(width: 30, height: 30)
                        .background(isListening ? Color.red.opacity(0.15) : AppTheme.subtle)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                barSep()

                FormatButton(icon: "text.viewfinder", isActive: false) {
                    isFocusMode = true
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 38)
        .background(
            Rectangle()
                .fill(AppTheme.sidebarBg.opacity(0.6))
                .overlay(
                    Rectangle()
                        .fill(AppTheme.subtle)
                )
        )
    }

    // MARK: - Color Palette

    private var textColorPalette: some View {
        let colors: [(String, Color, Double, Double, Double)] = [
            ("Default", .black, 0, 0, 0),
            ("Dark Gray", Color(red: 0.3, green: 0.3, blue: 0.3), 0.3, 0.3, 0.3),
            ("Red", Color(red: 0.85, green: 0.2, blue: 0.2), 0.85, 0.2, 0.2),
            ("Orange", Color(red: 0.9, green: 0.5, blue: 0.1), 0.9, 0.5, 0.1),
            ("Amber", Color(red: 0.8, green: 0.65, blue: 0.0), 0.8, 0.65, 0.0),
            ("Green", Color(red: 0.2, green: 0.65, blue: 0.3), 0.2, 0.65, 0.3),
            ("Teal", Color(red: 0.15, green: 0.6, blue: 0.6), 0.15, 0.6, 0.6),
            ("Blue", Color(red: 0.2, green: 0.4, blue: 0.8), 0.2, 0.4, 0.8),
            ("Indigo", Color(hex: 0x6366F1), 0.39, 0.4, 0.95),
            ("Purple", Color(red: 0.58, green: 0.34, blue: 0.8), 0.58, 0.34, 0.8),
            ("Pink", Color(red: 0.85, green: 0.3, blue: 0.5), 0.85, 0.3, 0.5),
            ("Brown", Color(red: 0.55, green: 0.35, blue: 0.2), 0.55, 0.35, 0.2),
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text("TEXT COLOR")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 6), spacing: 6) {
                ForEach(colors, id: \.0) { name, color, r, g, b in
                    Button {
                        selectedTextColor = color
                        formatAction = .textColor(red: r, green: g, blue: b)
                        showingColorPicker = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 26, height: 26)
                            if selectedTextColor == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(name)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
    }

    // MARK: - Voice Input

    @State private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    private func toggleVoiceInput() {
        if isListening { stopListening() } else { startListening() }
    }

    private func startListening() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch { return }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    let currentText = self.attributedContent.string
                    let separator = currentText.isEmpty ? "" : " "
                    let newText = currentText + separator + spokenText
                    #if canImport(UIKit)
                    let font = UIFont.preferredFont(forTextStyle: .body)
                    let color = UIColor.black.withAlphaComponent(0.8)
                    #else
                    let font = NSFont.preferredFont(forTextStyle: .body)
                    let color = NSColor.black.withAlphaComponent(0.8)
                    #endif
                    self.attributedContent = NSAttributedString(string: newText, attributes: [.font: font, .foregroundColor: color])
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
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Data

    private func loadPage() async {
        guard !isLoaded else { return }
        if let decrypted = await diaryManager.decryptPage(page) {
            title = decrypted.title
            selectedEmojis = decrypted.emojis
            if let contentData = decrypted.content {
                if let attributed = try? NSAttributedString(
                    data: contentData,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                ) {
                    attributedContent = attributed
                } else if let attributed = try? NSAttributedString(
                    data: contentData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ) {
                    attributedContent = attributed
                } else if let text = String(data: contentData, encoding: .utf8) {
                    attributedContent = NSAttributedString(string: text)
                }
            }
            let words = attributedContent.string.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            wordCount = words.count
        }
        isLoaded = true
    }

    private func saveNow() {
        Task {
            await savePageContent()
            showSaveIndicator = true
            try? await Task.sleep(for: .seconds(1.5))
            showSaveIndicator = false
        }
    }

    private func savePageContent() async {
        var contentData: Data?
        if attributedContent.length > 0 {
            contentData = try? attributedContent.data(
                from: NSRange(location: 0, length: attributedContent.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }
        await diaryManager.savePage(page, title: title, subtitle: nil, content: contentData, emojis: selectedEmojis)
    }
}

struct FormatButton: View {
    var icon: String?
    var label: String?
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .frame(width: 32, height: 32)
            .foregroundStyle(isActive ? AppTheme.accent : AppTheme.mutedText)
            .background(isActive ? AppTheme.accent.opacity(0.15) : AppTheme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let context = DataController.shared.container.mainContext
    let diary = Diary(name: "Test")
    let page = Page(diary: diary, date: Date())

    return PageEditorView(
        diaryManager: DiaryManager(modelContext: context),
        page: page,
        date: Date(),
        attachedImages: .constant([])
    )
    .background(AppTheme.bg)
}
