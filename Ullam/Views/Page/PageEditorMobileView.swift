import SwiftUI
import SwiftData
import Speech
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import AVFoundation
import PhotosUI
import Photos

struct PageEditorMobileView: View {
    @Bindable var diaryManager: DiaryManager
    let page: Page
    let date: Date

    // Content state
    @State private var title: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var selectedEmojis: [String] = []
    @State private var formatAction: FormatAction?
    @State private var isLoaded: Bool = false

    // UI state
    @State private var showingEmojiPicker = false
    @State private var showingImagePicker = false
    @State private var showingCameraPicker = false
    @State private var showingInsertMenu = false
    @State private var showAISheet = false
    @State private var isFocusMode = false
    @State private var isToolbarExpanded = false
    @State private var showSaveIndicator = false
    @State private var keyboardVisible = false
    @State private var wordCount: Int = 0
    @State private var hideToolbarWhileTyping = false
    @State private var typingTimer: Timer?

    // Voice state
    @State private var isListening = false
    @State private var isRecordingVoiceNote = false
    @State private var voiceRecordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    // Image state
    @State private var attachedImageData: [Data] = []

    @Environment(\.dismiss) private var dismiss

    private let maxEmojis = 3

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: page.createdAt)
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: page.createdAt)
    }

    private var showToolbar: Bool {
        !isFocusMode && !hideToolbarWhileTyping
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            editorBackground

            VStack(spacing: 0) {
                topBar.padding(.top, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        titleSection

                        if !isFocusMode {
                            metadataSection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if !selectedEmojis.isEmpty && !isFocusMode {
                            emojiTags.transition(.opacity)
                        }

                        // Attached images preview
                        if !attachedImageData.isEmpty && !isFocusMode {
                            imageAttachments.transition(.opacity)
                        }

                        // Voice recording indicator
                        if isListening || isRecordingVoiceNote {
                            voiceRecordingBanner.transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        if !isFocusMode { separatorLine }

                        editorSection
                    }
                }

                // Toolbar
                if showToolbar {
                    FloatingToolbar(
                        formatAction: $formatAction,
                        selectedEmojis: $selectedEmojis,
                        isExpanded: $isToolbarExpanded,
                        showingEmojiPicker: $showingEmojiPicker,
                        showingImagePicker: $showingImagePicker,
                        showingInsertMenu: $showingInsertMenu,
                        onVoiceTap: { toggleVoice() },
                        onDismissKeyboard: { dismissKeyboard() },
                        isListening: isListening,
                        maxEmojis: maxEmojis
                    )
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !keyboardVisible && !isFocusMode {
                    // Show mini floating button when keyboard is hidden
                    HStack {
                        Spacer()
                        Button {
                            // Re-focus the editor
                            withAnimation(.spring(response: 0.3)) {
                                hideToolbarWhileTyping = false
                            }
                        } label: {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(ToolbarButtonStyle())
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                    }
                    .transition(.opacity)
                }
            }

            // Focus exit
            if isFocusMode {
                focusExitOverlay
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isFocusMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showToolbar)
        .task { await loadPage() }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: .constant(nil)) { emoji in
                if selectedEmojis.count < maxEmojis {
                    withAnimation(.spring(response: 0.3)) { selectedEmojis.append(emoji) }
                    saveNow()
                }
                showingEmojiPicker = false
            }
            .presentationDetents([.medium])
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAISheet) {
            AIWritingSheet(isPresented: $showAISheet) { _ in }
            .presentationDetents([.medium])
            .presentationBackground(.clear)
        }
        .onChange(of: showingImagePicker) { _, show in
            if show { presentImagePicker() }
        }
        .onChange(of: showingCameraPicker) { _, show in
            if show { presentCamera() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardVisible = false
                hideToolbarWhileTyping = false
            }
        }
    }

    // MARK: - Background

    private var editorBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B1120), Color(hex: 0x0F172A), Color(hex: 0x160F2E)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            RadialGradient(colors: [AppTheme.accent.opacity(0.06), .clear], center: .init(x: 0.3, y: 0.0), startRadius: 20, endRadius: 350).ignoresSafeArea()
            RadialGradient(colors: [AppTheme.gradientPink.opacity(0.03), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 300).ignoresSafeArea()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Group {
                if showSaveIndicator {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                        Text("Saved").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.accent.opacity(0.7))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if wordCount > 0 {
                    Text("\(wordCount) words")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSaveIndicator)

            Spacer()

            if !isFocusMode {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isFocusMode = true }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.04))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(ToolbarButtonStyle())
            }

            Button {
                dismiss()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [AppTheme.accent.opacity(0.5), Color(hex: 0x7C3AED).opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    )
                    .shadow(color: AppTheme.accent.opacity(0.2), radius: 12, y: 4)
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Title

    private var titleSection: some View {
        TextField("Give your thoughts a title\u{2026}", text: $title)
            .font(.custom("NewYork-Bold", size: 28, relativeTo: .largeTitle))
            .foregroundStyle(.white.opacity(title.isEmpty ? 0.18 : 0.92))
            .textFieldStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, isFocusMode ? 24 : 14)
            .padding(.bottom, 6)
            .onChange(of: title) { _, _ in saveNow(); markTyping() }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Image(systemName: "calendar").font(.system(size: 10))
                Text(formattedDate).font(.system(size: 12, weight: .medium))
            }.foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 5) {
                Image(systemName: "clock").font(.system(size: 10))
                Text(formattedTime).font(.system(size: 12, weight: .medium))
            }.foregroundStyle(.white.opacity(0.25))

            Spacer()

            Button {
                showAISheet = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.accent.opacity(0.45))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.03))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.accent.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
    }

    // MARK: - Emoji Tags

    private var emojiTags: some View {
        HStack(spacing: 6) {
            ForEach(Array(selectedEmojis.enumerated()), id: \.offset) { index, emoji in
                Button {
                    withAnimation(.spring(response: 0.25)) { selectedEmojis.remove(at: index) }
                    saveNow()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(emoji)
                        .font(.system(size: 16))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(ToolbarButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    // MARK: - Image Attachments

    private var imageAttachments: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(attachedImageData.enumerated()), id: \.offset) { index, data in
                    if let uiImage = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.white.opacity(0.08), lineWidth: 1)
                                )

                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    attachedImageData.remove(at: index)
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 12)
    }

    // MARK: - Voice Recording Banner

    private var voiceRecordingBanner: some View {
        HStack(spacing: 12) {
            // Pulsing red dot
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .shadow(color: .red.opacity(0.5), radius: 4)
                .scaleEffect(isListening ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isListening)

            if isRecordingVoiceNote {
                Text("Recording voice note\u{2026}")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Listening\u{2026}")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(formatDuration(voiceRecordingDuration))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            Button {
                stopListening()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.red.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.red.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Separator

    private var separatorLine: some View {
        LinearGradient(colors: [.clear, .white.opacity(0.06), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    // MARK: - Editor

    private var editorSection: some View {
        RichTextEditor(
            attributedText: $attributedContent,
            placeholder: "What\u{2019}s on your mind?",
            focusOnAppear: !title.isEmpty,
            formatAction: $formatAction,
            onTextChange: { newText in
                saveNow()
                markTyping()
                let words = newText.string.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                wordCount = words.count
            }
        )
        .frame(minHeight: 400)
        .padding(.horizontal, 4)
    }

    // MARK: - Focus Exit

    private var focusExitOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isFocusMode = false }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "eye").font(.system(size: 11, weight: .medium))
                        Text("Exit Focus").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(ToolbarButtonStyle())
                .padding(.trailing, 20).padding(.top, 8)
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Typing Management

    private func markTyping() {
        if !hideToolbarWhileTyping && keyboardVisible {
            withAnimation(.easeOut(duration: 0.2)) { hideToolbarWhileTyping = true }
        }
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.25)) { hideToolbarWhileTyping = false }
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - UIKit Presenters (avoids _UIReparentingView)

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return nil }
        var vc = rootVC
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }

    private func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 5
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        let delegate = ImagePickerDelegate { [self] images in
            withAnimation(.spring(response: 0.3)) {
                attachedImageData.append(contentsOf: images)
            }
            showingImagePicker = false
        }
        // Store delegate to keep it alive
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        picker.delegate = delegate
        topViewController()?.present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingCameraPicker = false
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        let delegate = CameraDelegate { [self] data in
            if let data {
                withAnimation(.spring(response: 0.3)) {
                    attachedImageData.append(data)
                }
            }
            showingCameraPicker = false
        }
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        picker.delegate = delegate
        topViewController()?.present(picker, animated: true)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
            voiceRecordingDuration = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async { voiceRecordingDuration += 1 }
            }
        } catch { return }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    let current = self.attributedContent.string
                    let sep = current.isEmpty ? "" : " "
                    let font = UIFont.systemFont(ofSize: 17)
                    self.attributedContent = NSAttributedString(
                        string: current + sep + text,
                        attributes: [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.8)]
                    )
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
        recordingTimer?.invalidate()
        recordingTimer = nil
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
                let words = attr.string.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                wordCount = words.count
            }
        }
        isLoaded = true
    }

    private func saveNow() {
        Task {
            var contentData: Data?
            if attributedContent.length > 0 {
                contentData = try? attributedContent.data(
                    from: NSRange(location: 0, length: attributedContent.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
            }
            await diaryManager.savePage(page, title: title, subtitle: nil, content: contentData, emojis: selectedEmojis)
            showSaveIndicator = true
            try? await Task.sleep(for: .seconds(1.5))
            showSaveIndicator = false
        }
    }
}

// MARK: - UIKit Delegates (presented directly, not through SwiftUI sheet system)

class ImagePickerDelegate: NSObject, PHPickerViewControllerDelegate {
    let onPick: ([Data]) -> Void
    init(onPick: @escaping ([Data]) -> Void) { self.onPick = onPick }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        var images: [Data] = []
        let group = DispatchGroup()
        for result in results {
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                    images.append(data)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [self] in
            onPick(images)
        }
    }
}

class CameraDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onCapture: (Data?) -> Void
    init(onCapture: @escaping (Data?) -> Void) { self.onCapture = onCapture }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        onCapture(image?.jpegData(compressionQuality: 0.8))
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onCapture(nil)
        picker.dismiss(animated: true)
    }
}

#endif // canImport(UIKit)
