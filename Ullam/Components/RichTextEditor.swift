import SwiftUI
#if canImport(UIKit)
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var placeholder: String
    var onTextChange: ((NSAttributedString) -> Void)?
    var focusOnAppear: Bool

    @Binding var formatAction: FormatAction?

    init(
        attributedText: Binding<NSAttributedString>,
        placeholder: String = "Start writing...",
        focusOnAppear: Bool = true,
        formatAction: Binding<FormatAction?> = .constant(nil),
        onTextChange: ((NSAttributedString) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self.placeholder = placeholder
        self.focusOnAppear = focusOnAppear
        self._formatAction = formatAction
        self.onTextChange = onTextChange
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        textView.attributedText = attributedText

        // Setup placeholder
        context.coordinator.textView = textView
        context.coordinator.updatePlaceholder()

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Handle format actions
        if let action = formatAction {
            DispatchQueue.main.async {
                context.coordinator.applyFormat(action)
                self.formatAction = nil
            }
        }

        // Update text if changed externally
        if textView.attributedText.string != attributedText.string {
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedText
            if selectedRange.location <= textView.text.count {
                textView.selectedRange = selectedRange
            }
        }

        // Focus on appear
        if focusOnAppear && !context.coordinator.hasFocused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textView.becomeFirstResponder()
                context.coordinator.hasFocused = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        var hasFocused = false

        private var placeholderLabel: UILabel?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func updatePlaceholder() {
            guard let textView = textView else { return }

            if placeholderLabel == nil {
                let label = UILabel()
                label.text = parent.placeholder
                label.font = .preferredFont(forTextStyle: .body)
                label.textColor = .placeholderText
                label.translatesAutoresizingMaskIntoConstraints = false
                textView.addSubview(label)

                NSLayoutConstraint.activate([
                    label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 20),
                    label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 21)
                ])

                placeholderLabel = label
            }

            placeholderLabel?.isHidden = !textView.text.isEmpty
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.onTextChange?(textView.attributedText)
            updatePlaceholder()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            updatePlaceholder()
        }

        // MARK: - Formatting

        func applyFormat(_ action: FormatAction) {
            guard let textView = textView else { return }

            switch action {
            case .bold:
                toggleTrait(.traitBold)
            case .italic:
                toggleTrait(.traitItalic)
            case .underline:
                toggleUnderline()
            case .strikethrough:
                toggleStrikethrough()
            case .quote:
                applyQuoteStyle()
            case .heading:
                applyTextStyle(.title2)
            case .subheading:
                applyTextStyle(.title3)
            case .body:
                applyTextStyle(.body)
            case .bulletList:
                insertListPrefix("•  ")
            case .numberedList:
                insertListPrefix("1. ")
            case .highlight:
                applyHighlight()
            case .separator:
                insertSeparator()
            case .textColor(let r, let g, let b):
                applyTextColor(UIColor(red: r, green: g, blue: b, alpha: 1.0))
            }

            parent.attributedText = textView.attributedText
            parent.onTextChange?(textView.attributedText)
        }

        private func applyTextColor(_ color: UIColor) {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                var attrs = textView.typingAttributes
                attrs[.foregroundColor] = color
                textView.typingAttributes = attrs
                return
            }
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.addAttribute(.foregroundColor, value: color, range: range)
            textView.attributedText = mutableText
            textView.selectedRange = range
        }

        private func toggleStrikethrough() {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                var attrs = textView.typingAttributes
                let has = (attrs[.strikethroughStyle] as? Int) != nil && (attrs[.strikethroughStyle] as? Int) != 0
                attrs[.strikethroughStyle] = has ? 0 : NSUnderlineStyle.single.rawValue
                textView.typingAttributes = attrs
                return
            }
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            var hasStrike = false
            mutableText.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, stop in
                if let v = value as? Int, v != 0 { hasStrike = true; stop.pointee = true }
            }
            if hasStrike {
                mutableText.removeAttribute(.strikethroughStyle, range: range)
            } else {
                mutableText.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            textView.attributedText = mutableText
            textView.selectedRange = range
        }

        private func insertListPrefix(_ prefix: String) {
            guard let textView = textView else { return }
            let cursorPos = textView.selectedRange.location
            let text = textView.text as NSString
            let lineRange = text.lineRange(for: NSRange(location: cursorPos, length: 0))
            let lineStart = lineRange.location
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let prefixAttr = NSAttributedString(string: prefix, attributes: textView.typingAttributes)
            mutableText.insert(prefixAttr, at: lineStart)
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: cursorPos + prefix.count, length: 0)
        }

        private func applyHighlight() {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            guard range.length > 0 else { return }
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            var hasHighlight = false
            mutableText.enumerateAttribute(.backgroundColor, in: range, options: []) { value, _, stop in
                if value != nil { hasHighlight = true; stop.pointee = true }
            }
            if hasHighlight {
                mutableText.removeAttribute(.backgroundColor, range: range)
            } else {
                mutableText.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: range)
            }
            textView.attributedText = mutableText
            textView.selectedRange = range
        }

        private func insertSeparator() {
            guard let textView = textView else { return }
            let cursorPos = textView.selectedRange.location
            let sepString = "\n\n———————\n\n"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let sepAttr = NSAttributedString(string: sepString, attributes: attrs)
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.insert(sepAttr, at: cursorPos)
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: cursorPos + sepString.count, length: 0)
        }

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView = textView else { return }
            let range = textView.selectedRange

            // If no selection, toggle typing attributes for next typed text
            if range.length == 0 {
                var attrs = textView.typingAttributes
                let currentFont = (attrs[.font] as? UIFont) ?? .preferredFont(forTextStyle: .body)
                var newTraits = currentFont.fontDescriptor.symbolicTraits
                if newTraits.contains(trait) {
                    newTraits.remove(trait)
                } else {
                    newTraits.insert(trait)
                }
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                    attrs[.font] = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    textView.typingAttributes = attrs
                }
                return
            }

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)

            mutableText.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                guard let currentFont = value as? UIFont else { return }

                var newTraits = currentFont.fontDescriptor.symbolicTraits
                if newTraits.contains(trait) {
                    newTraits.remove(trait)
                } else {
                    newTraits.insert(trait)
                }

                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                    let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    mutableText.addAttribute(.font, value: newFont, range: subRange)
                }
            }

            textView.attributedText = mutableText
            textView.selectedRange = range
        }

        private func toggleUnderline() {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            guard range.length > 0 else { return }

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)

            var hasUnderline = false
            mutableText.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                if value != nil {
                    hasUnderline = true
                    stop.pointee = true
                }
            }

            if hasUnderline {
                mutableText.removeAttribute(.underlineStyle, range: range)
            } else {
                mutableText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }

            textView.attributedText = mutableText
            textView.selectedRange = range
        }

        private func applyQuoteStyle() {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            guard range.length > 0 else { return }

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 16
            paragraphStyle.headIndent = 16
            paragraphStyle.tailIndent = -16

            mutableText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            mutableText.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: range)

            textView.attributedText = mutableText
            textView.selectedRange = range
        }

        private func applyTextStyle(_ style: UIFont.TextStyle) {
            guard let textView = textView else { return }
            let range = textView.selectedRange
            guard range.length > 0 else { return }

            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let font = UIFont.preferredFont(forTextStyle: style)
            mutableText.addAttribute(.font, value: font, range: range)

            if style == .body {
                mutableText.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 0
                mutableText.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }

            textView.attributedText = mutableText
            textView.selectedRange = range
        }
    }
}

enum FormatAction {
    case bold
    case italic
    case underline
    case strikethrough
    case quote
    case heading
    case subheading
    case body
    case bulletList
    case numberedList
    case highlight
    case separator
    case textColor(red: Double, green: Double, blue: Double)
}

#else
// macOS implementation using NSTextView
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var placeholder: String
    var onTextChange: ((NSAttributedString) -> Void)?
    var focusOnAppear: Bool

    @Binding var formatAction: FormatAction?

    init(
        attributedText: Binding<NSAttributedString>,
        placeholder: String = "Start writing...",
        focusOnAppear: Bool = true,
        formatAction: Binding<FormatAction?> = .constant(nil),
        onTextChange: ((NSAttributedString) -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self.placeholder = placeholder
        self.focusOnAppear = focusOnAppear
        self._formatAction = formatAction
        self.onTextChange = onTextChange
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 16, height: 20)
        textView.textStorage?.setAttributedString(attributedText)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .black.withAlphaComponent(0.8)
        textView.insertionPointColor = .black.withAlphaComponent(0.6)
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Handle format actions
        if let action = formatAction {
            DispatchQueue.main.async {
                context.coordinator.applyFormat(action)
                self.formatAction = nil
            }
        }

        // Update text if changed externally (e.g., when loading a page)
        if textView.string != attributedText.string {
            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            if selectedRange.location <= textView.string.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // Focus on appear
        if focusOnAppear && !context.coordinator.hasFocused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textView.window?.makeFirstResponder(textView)
                context.coordinator.hasFocused = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        weak var textView: NSTextView?
        var hasFocused = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let newText = textView.attributedString()
            parent.attributedText = newText
            parent.onTextChange?(newText)
        }

        func applyFormat(_ action: FormatAction) {
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }

            let range = textView.selectedRange()

            // If no selection, toggle typing attributes for next typed text
            if range.length == 0 {
                var attrs = textView.typingAttributes
                switch action {
                case .bold:
                    toggleTypingTrait(.bold, attrs: &attrs)
                case .italic:
                    toggleTypingTrait(.italic, attrs: &attrs)
                case .underline:
                    let has = (attrs[.underlineStyle] as? Int) != nil && (attrs[.underlineStyle] as? Int) != 0
                    attrs[.underlineStyle] = has ? 0 : NSUnderlineStyle.single.rawValue
                case .heading:
                    attrs[.font] = NSFont.preferredFont(forTextStyle: .title2)
                case .subheading:
                    attrs[.font] = NSFont.preferredFont(forTextStyle: .title3)
                case .body:
                    attrs[.font] = NSFont.preferredFont(forTextStyle: .body)
                case .quote:
                    let ps = NSMutableParagraphStyle()
                    ps.firstLineHeadIndent = 16
                    ps.headIndent = 16
                    attrs[.paragraphStyle] = ps
                    attrs[.foregroundColor] = NSColor.secondaryLabelColor
                case .strikethrough:
                    let has = (attrs[.strikethroughStyle] as? Int) != nil && (attrs[.strikethroughStyle] as? Int) != 0
                    attrs[.strikethroughStyle] = has ? 0 : NSUnderlineStyle.single.rawValue
                case .textColor(let r, let g, let b):
                    attrs[.foregroundColor] = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                case .bulletList, .numberedList, .highlight, .separator:
                    break // handled below with range
                }
                textView.typingAttributes = attrs
                return
            }

            switch action {
            case .bold:
                toggleTrait(.bold, in: textStorage, range: range)
            case .italic:
                toggleTrait(.italic, in: textStorage, range: range)
            case .underline:
                toggleUnderline(in: textStorage, range: range)
            case .strikethrough:
                toggleStrikethrough(in: textStorage, range: range)
            case .quote:
                applyQuoteStyle(in: textStorage, range: range)
            case .heading:
                applyTextStyle(.title2, in: textStorage, range: range)
            case .subheading:
                applyTextStyle(.title3, in: textStorage, range: range)
            case .body:
                applyTextStyle(.body, in: textStorage, range: range)
            case .bulletList:
                insertListPrefixMac("•  ")
            case .numberedList:
                insertListPrefixMac("1. ")
            case .highlight:
                applyHighlightMac(in: textStorage, range: range)
            case .separator:
                insertSeparatorMac()
            case .textColor(let r, let g, let b):
                applyTextColorMac(NSColor(red: r, green: g, blue: b, alpha: 1.0), in: textStorage, range: range)
            }

            textView.setSelectedRange(range)
            parent.attributedText = textView.attributedString()
            parent.onTextChange?(textView.attributedString())
        }

        private func applyTextColorMac(_ color: NSColor, in textStorage: NSTextStorage, range: NSRange) {
            if range.length == 0 {
                guard let textView = textView else { return }
                var attrs = textView.typingAttributes
                attrs[.foregroundColor] = color
                textView.typingAttributes = attrs
                return
            }
            textStorage.addAttribute(.foregroundColor, value: color, range: range)
        }

        private func toggleTypingTrait(_ trait: NSFontDescriptor.SymbolicTraits, attrs: inout [NSAttributedString.Key: Any]) {
            let currentFont = (attrs[.font] as? NSFont) ?? .preferredFont(forTextStyle: .body)
            var newTraits = currentFont.fontDescriptor.symbolicTraits
            if newTraits.contains(trait) {
                newTraits.remove(trait)
            } else {
                newTraits.insert(trait)
            }
            let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits)
            attrs[.font] = NSFont(descriptor: descriptor, size: currentFont.pointSize) ?? currentFont
        }

        private func toggleStrikethrough(in textStorage: NSTextStorage, range: NSRange) {
            var hasStrike = false
            textStorage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, stop in
                if let v = value as? Int, v != 0 { hasStrike = true; stop.pointee = true }
            }
            if hasStrike {
                textStorage.removeAttribute(.strikethroughStyle, range: range)
            } else {
                textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }

        private func insertListPrefixMac(_ prefix: String) {
            guard let textView = textView, let textStorage = textView.textStorage else { return }
            let cursorPos = textView.selectedRange().location
            let nsString = textView.string as NSString
            let lineRange = nsString.lineRange(for: NSRange(location: cursorPos, length: 0))
            let prefixAttr = NSAttributedString(string: prefix, attributes: textView.typingAttributes)
            textStorage.insert(prefixAttr, at: lineRange.location)
            textView.setSelectedRange(NSRange(location: cursorPos + prefix.count, length: 0))
            parent.attributedText = textView.attributedString()
            parent.onTextChange?(textView.attributedString())
        }

        private func applyHighlightMac(in textStorage: NSTextStorage, range: NSRange) {
            guard range.length > 0 else { return }
            var hasHighlight = false
            textStorage.enumerateAttribute(.backgroundColor, in: range, options: []) { value, _, stop in
                if value != nil { hasHighlight = true; stop.pointee = true }
            }
            if hasHighlight {
                textStorage.removeAttribute(.backgroundColor, range: range)
            } else {
                textStorage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: range)
            }
        }

        private func insertSeparatorMac() {
            guard let textView = textView, let textStorage = textView.textStorage else { return }
            let cursorPos = textView.selectedRange().location
            let sepString = "\n\n———————\n\n"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.preferredFont(forTextStyle: .body),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let sepAttr = NSAttributedString(string: sepString, attributes: attrs)
            textStorage.insert(sepAttr, at: cursorPos)
            textView.setSelectedRange(NSRange(location: cursorPos + sepString.count, length: 0))
            parent.attributedText = textView.attributedString()
            parent.onTextChange?(textView.attributedString())
        }

        private func toggleTrait(_ trait: NSFontDescriptor.SymbolicTraits, in textStorage: NSTextStorage, range: NSRange) {
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                guard let currentFont = value as? NSFont else { return }

                var newTraits = currentFont.fontDescriptor.symbolicTraits
                if newTraits.contains(trait) {
                    newTraits.remove(trait)
                } else {
                    newTraits.insert(trait)
                }

                let descriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits)
                let newFont = NSFont(descriptor: descriptor, size: currentFont.pointSize) ?? currentFont
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }

        private func toggleUnderline(in textStorage: NSTextStorage, range: NSRange) {
            var hasUnderline = false
            textStorage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                if value != nil {
                    hasUnderline = true
                    stop.pointee = true
                }
            }

            if hasUnderline {
                textStorage.removeAttribute(.underlineStyle, range: range)
            } else {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }

        private func applyQuoteStyle(in textStorage: NSTextStorage, range: NSRange) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 16
            paragraphStyle.headIndent = 16
            paragraphStyle.tailIndent = -16

            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
        }

        private func applyTextStyle(_ style: NSFont.TextStyle, in textStorage: NSTextStorage, range: NSRange) {
            let font = NSFont.preferredFont(forTextStyle: style)
            textStorage.addAttribute(.font, value: font, range: range)

            if style == .body {
                textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 0
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }
        }
    }
}

enum FormatAction {
    case bold
    case italic
    case underline
    case strikethrough
    case quote
    case heading
    case subheading
    case body
    case bulletList
    case numberedList
    case highlight
    case separator
    case textColor(red: Double, green: Double, blue: Double)
}
#endif
