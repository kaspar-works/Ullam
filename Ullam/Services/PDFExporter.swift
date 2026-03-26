import Foundation
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Platform Type Aliases

#if canImport(UIKit)
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#else
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#endif

/// Generates a multi-page PDF from diary pages with nice typography and layout.
/// Works on both iOS (UIKit) and macOS (AppKit) using Core Graphics + Core Text.
final class PDFExporter {

    // MARK: - Layout Constants

    private static let pageWidth: CGFloat = 612    // US Letter
    private static let pageHeight: CGFloat = 792
    private static let marginX: CGFloat = 56
    private static let marginTop: CGFloat = 56
    private static let marginBottom: CGFloat = 56
    private static var contentWidth: CGFloat { pageWidth - marginX * 2 }

    // MARK: - Public API

    /// Export an array of page data into a styled PDF document.
    /// - Parameters:
    ///   - pages: Decoded page tuples sorted however the caller prefers.
    ///   - diaryName: The name of the diary, displayed in the first-page header.
    /// - Returns: Raw PDF `Data`, or `nil` if rendering fails.
    static func exportPages(
        _ pages: [(title: String, body: String, date: Date, emojis: [String])],
        diaryName: String
    ) -> Data? {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        var cursorY: CGFloat = 0

        // --- Helpers that capture cgContext ---

        func beginNewPage() {
            cgContext.endPDFPage()
            cgContext.beginPDFPage(nil)
            // Flip coordinate system so (0,0) is top-left
            cgContext.translateBy(x: 0, y: pageHeight)
            cgContext.scaleBy(x: 1, y: -1)
            cursorY = marginTop
        }

        func ensureSpace(_ needed: CGFloat) {
            if cursorY + needed > pageHeight - marginBottom {
                beginNewPage()
            }
        }

        // Start first page
        cgContext.beginPDFPage(nil)
        cgContext.translateBy(x: 0, y: pageHeight)
        cgContext.scaleBy(x: 1, y: -1)
        cursorY = marginTop

        // ------------------------------------------------------------------
        // Cover / first-page header
        // ------------------------------------------------------------------

        // Diary name
        let diaryNameAttrs = makeAttrs(
            font: serifFont(size: 28, weight: .bold),
            color: darkTextColor()
        )
        let diaryNameStr = NSAttributedString(string: diaryName, attributes: diaryNameAttrs)
        drawAttributedString(diaryNameStr, in: cgContext, x: marginX, y: cursorY, width: contentWidth)
        let nameHeight = measureHeight(diaryNameStr, width: contentWidth)
        cursorY += nameHeight + 8

        // Export info subtitle
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let exportDate = dateFormatter.string(from: Date())
        let subtitleAttrs = makeAttrs(
            font: sansFont(size: 12, weight: .regular),
            color: grayColor(0.45)
        )
        let subtitleStr = NSAttributedString(
            string: "Exported on \(exportDate)  \u{00B7}  \(pages.count) page\(pages.count == 1 ? "" : "s")",
            attributes: subtitleAttrs
        )
        drawAttributedString(subtitleStr, in: cgContext, x: marginX, y: cursorY, width: contentWidth)
        cursorY += 24

        // Divider
        drawDivider(in: cgContext, x: marginX, y: cursorY, width: contentWidth)
        cursorY += 20

        // ------------------------------------------------------------------
        // Entries
        // ------------------------------------------------------------------

        let entryDateFormatter = DateFormatter()
        entryDateFormatter.dateFormat = "EEEE, MMMM d, yyyy"

        for (index, page) in pages.enumerated() {

            ensureSpace(80)

            // Date label
            let dateAttrs = makeAttrs(
                font: sansFont(size: 11, weight: .medium),
                color: grayColor(0.5),
                kern: 1.2
            )
            let dateStr = NSAttributedString(
                string: entryDateFormatter.string(from: page.date).uppercased(),
                attributes: dateAttrs
            )
            drawAttributedString(dateStr, in: cgContext, x: marginX, y: cursorY, width: contentWidth)
            cursorY += 20

            // Title
            let titleText = page.title.isEmpty ? "Untitled" : page.title
            let titleAttrs = makeAttrs(
                font: serifFont(size: 20, weight: .bold),
                color: darkTextColor()
            )
            let titleAttrStr = NSAttributedString(string: titleText, attributes: titleAttrs)
            let titleHeight = measureHeight(titleAttrStr, width: contentWidth)
            ensureSpace(titleHeight + 6)
            drawAttributedString(titleAttrStr, in: cgContext, x: marginX, y: cursorY, width: contentWidth)
            cursorY += titleHeight + 8

            // Emojis
            if !page.emojis.isEmpty {
                let emojiText = page.emojis.joined(separator: "  ")
                let emojiAttrs = makeAttrs(
                    font: sansFont(size: 16, weight: .regular),
                    color: darkTextColor()
                )
                let emojiStr = NSAttributedString(string: emojiText, attributes: emojiAttrs)
                ensureSpace(26)
                drawAttributedString(emojiStr, in: cgContext, x: marginX, y: cursorY, width: contentWidth)
                cursorY += 28
            }

            // Body text (may span multiple pages)
            if !page.body.isEmpty {
                let bodyParaStyle = NSMutableParagraphStyle()
                bodyParaStyle.lineSpacing = 5
                bodyParaStyle.paragraphSpacing = 8

                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: serifFont(size: 13, weight: .regular),
                    .foregroundColor: grayColor(0.2),
                    .paragraphStyle: bodyParaStyle
                ]
                let bodyAttrStr = NSAttributedString(string: page.body, attributes: bodyAttrs)

                cursorY = drawPaginatedText(
                    bodyAttrStr,
                    in: cgContext,
                    startY: cursorY,
                    beginNewPage: {
                        beginNewPage()
                        return cursorY
                    },
                    getCursorY: { cursorY },
                    setCursorY: { cursorY = $0 }
                )
            }

            // Entry separator
            if index < pages.count - 1 {
                cursorY += 14
                ensureSpace(30)
                drawDivider(in: cgContext, x: marginX, y: cursorY, width: contentWidth)
                cursorY += 22
            }
        }

        cgContext.endPDFPage()
        cgContext.closePDF()

        return data as Data
    }

    // MARK: - Core Text Drawing

    /// Draw an attributed string at (x, y) in a top-left-origin (flipped) context.
    /// This uses Core Text for reliable cross-platform rendering.
    private static func drawAttributedString(
        _ attrStr: NSAttributedString,
        in cgContext: CGContext,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let height = measureHeight(attrStr, width: width) + 4
        let frameSetter = CTFramesetterCreateWithAttributedString(attrStr)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, attrStr.length), path, nil)

        cgContext.saveGState()
        // We are already in a flipped context (y goes down). Core Text expects
        // an unflipped context (y goes up), so we flip again locally.
        cgContext.translateBy(x: x, y: y + height)
        cgContext.scaleBy(x: 1, y: -1)
        CTFrameDraw(frame, cgContext)
        cgContext.restoreGState()
    }

    /// Draw long text that may span multiple PDF pages, calling `beginNewPage` as needed.
    private static func drawPaginatedText(
        _ attrString: NSAttributedString,
        in cgContext: CGContext,
        startY: CGFloat,
        beginNewPage: () -> CGFloat,
        getCursorY: () -> CGFloat,
        setCursorY: (CGFloat) -> Void
    ) -> CGFloat {
        let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
        let totalLength = attrString.length
        var charIndex = 0
        var cursorY = startY

        while charIndex < totalLength {
            let availableHeight = pageHeight - marginBottom - cursorY
            if availableHeight < 24 {
                _ = beginNewPage()
                cursorY = getCursorY()
                continue
            }

            let path = CGPath(
                rect: CGRect(x: 0, y: 0, width: contentWidth, height: availableHeight),
                transform: nil
            )
            let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(charIndex, 0), path, nil)
            let visibleRange = CTFrameGetVisibleStringRange(frame)

            if visibleRange.length == 0 { break }

            // Draw this chunk
            cgContext.saveGState()
            cgContext.translateBy(x: marginX, y: cursorY + availableHeight)
            cgContext.scaleBy(x: 1, y: -1)
            CTFrameDraw(frame, cgContext)
            cgContext.restoreGState()

            let usedHeight = heightOfCTFrame(frame, maxHeight: availableHeight)
            cursorY += usedHeight
            charIndex += visibleRange.length

            if charIndex < totalLength {
                _ = beginNewPage()
                cursorY = getCursorY()
            }
        }

        return cursorY
    }

    /// Measure the actual height used by a CTFrame.
    private static func heightOfCTFrame(_ frame: CTFrame, maxHeight: CGFloat) -> CGFloat {
        guard let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty else { return 0 }

        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), &origins)

        let lastOrigin = origins[lines.count - 1]
        var descent: CGFloat = 0
        CTLineGetTypographicBounds(lines[lines.count - 1], nil, &descent, nil)

        return maxHeight - lastOrigin.y + descent
    }

    // MARK: - Divider

    private static func drawDivider(in cgContext: CGContext, x: CGFloat, y: CGFloat, width: CGFloat) {
        cgContext.setStrokeColor(CGColor(gray: 0.82, alpha: 1))
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: x, y: y))
        cgContext.addLine(to: CGPoint(x: x + width, y: y))
        cgContext.strokePath()
    }

    // MARK: - Measurement

    private static func measureHeight(_ attrStr: NSAttributedString, width: CGFloat) -> CGFloat {
        let frameSetter = CTFramesetterCreateWithAttributedString(attrStr)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            frameSetter, CFRangeMake(0, attrStr.length), nil,
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), nil
        )
        return ceil(size.height)
    }

    // MARK: - Font Helpers

    private enum FontWeight { case regular, medium, bold }

    private static func serifFont(size: CGFloat, weight: FontWeight) -> PlatformFont {
        #if canImport(UIKit)
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        guard let serifDesc = base.withDesign(.serif) else {
            return UIFont.systemFont(ofSize: size)
        }
        switch weight {
        case .bold:
            return UIFont(descriptor: serifDesc.withSymbolicTraits(.traitBold) ?? serifDesc, size: size)
        case .medium, .regular:
            return UIFont(descriptor: serifDesc, size: size)
        }
        #else
        let base = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
        guard let serifDesc = base.withDesign(.serif) else {
            return NSFont.systemFont(ofSize: size)
        }
        switch weight {
        case .bold:
            let boldDesc = serifDesc.withSymbolicTraits(.bold)
            return NSFont(descriptor: boldDesc, size: size) ?? NSFont.boldSystemFont(ofSize: size)
        case .medium, .regular:
            return NSFont(descriptor: serifDesc, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        #endif
    }

    private static func sansFont(size: CGFloat, weight: FontWeight) -> PlatformFont {
        #if canImport(UIKit)
        switch weight {
        case .bold:   return UIFont.systemFont(ofSize: size, weight: .bold)
        case .medium: return UIFont.systemFont(ofSize: size, weight: .medium)
        case .regular: return UIFont.systemFont(ofSize: size, weight: .regular)
        }
        #else
        switch weight {
        case .bold:   return NSFont.systemFont(ofSize: size, weight: .bold)
        case .medium: return NSFont.systemFont(ofSize: size, weight: .medium)
        case .regular: return NSFont.systemFont(ofSize: size, weight: .regular)
        }
        #endif
    }

    // MARK: - Color Helpers

    private static func darkTextColor() -> PlatformColor {
        #if canImport(UIKit)
        return UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
        #else
        return NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
        #endif
    }

    private static func grayColor(_ brightness: CGFloat) -> PlatformColor {
        #if canImport(UIKit)
        return UIColor(white: brightness, alpha: 1)
        #else
        return NSColor(white: brightness, alpha: 1)
        #endif
    }

    private static func makeAttrs(
        font: PlatformFont,
        color: PlatformColor,
        kern: CGFloat? = nil
    ) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        if let kern = kern {
            attrs[.kern] = kern as NSNumber
        }
        return attrs
    }
}
