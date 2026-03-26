import SwiftUI

// MARK: - App Typography

/// Ullam uses a combination of serif and sans-serif fonts for a warm, literary feel.
/// Primary: New York (serif) - for headings and emphasis
/// Secondary: SF Pro (system) - for body text and UI elements

extension Font {
    // MARK: - Display & Titles

    /// Large display text for onboarding and splash screens
    static let appLargeTitle = Font.custom("NewYork-Bold", size: 32, relativeTo: .largeTitle)

    /// Main titles for screens
    static let appTitle = Font.custom("NewYork-Bold", size: 28, relativeTo: .title)

    /// Secondary titles
    static let appTitle2 = Font.custom("NewYork-Semibold", size: 22, relativeTo: .title2)

    /// Tertiary titles
    static let appTitle3 = Font.custom("NewYork-Medium", size: 20, relativeTo: .title3)

    // MARK: - Headlines & Subheadlines

    /// Headlines for sections
    static let appHeadline = Font.custom("NewYork-Semibold", size: 17, relativeTo: .headline)

    /// Subheadlines for secondary information
    static let appSubheadline = Font.custom("NewYork-Regular", size: 15, relativeTo: .subheadline)

    // MARK: - Body Text

    /// Primary body text
    static let appBody = Font.system(size: 17, weight: .regular, design: .default)

    /// Secondary body text
    static let appBodySecondary = Font.system(size: 15, weight: .regular, design: .default)

    // MARK: - Captions & Labels

    /// Small captions
    static let appCaption = Font.system(size: 12, weight: .regular, design: .default)

    /// Bold captions for emphasis
    static let appCaptionBold = Font.system(size: 12, weight: .semibold, design: .default)

    /// Tiny labels
    static let appFootnote = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Special Styles

    /// For diary entry titles
    static let diaryTitle = Font.custom("NewYork-Bold", size: 24, relativeTo: .title2)

    /// For diary entry body
    static let diaryBody = Font.custom("NewYork-Regular", size: 17, relativeTo: .body)

    /// For button labels
    static let buttonLabel = Font.custom("NewYork-Semibold", size: 17, relativeTo: .body)

    /// For navigation bar titles
    static let navTitle = Font.custom("NewYork-Semibold", size: 17, relativeTo: .headline)

    /// For tab bar labels
    static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)

    /// Monospace for pincodes
    static let pincode = Font.system(size: 32, weight: .light, design: .monospaced)
}

// MARK: - View Modifiers

extension View {
    /// Apply app's large title style
    func appLargeTitleStyle() -> some View {
        self.font(.appLargeTitle)
    }

    /// Apply app's title style
    func appTitleStyle() -> some View {
        self.font(.appTitle)
    }

    /// Apply app's headline style
    func appHeadlineStyle() -> some View {
        self.font(.appHeadline)
    }

    /// Apply app's body style
    func appBodyStyle() -> some View {
        self.font(.appBody)
    }

    /// Apply app's caption style
    func appCaptionStyle() -> some View {
        self.font(.appCaption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Text Styles

extension Text {
    /// Styled as app large title
    func appLargeTitle() -> Text {
        self.font(.appLargeTitle)
    }

    /// Styled as app title
    func appTitle() -> Text {
        self.font(.appTitle)
    }

    /// Styled as app headline
    func appHeadline() -> Text {
        self.font(.appHeadline)
    }

    /// Styled as app body
    func appBody() -> Text {
        self.font(.appBody)
    }

    /// Styled as app caption
    func appCaption() -> Text {
        self.font(.appCaption)
            .foregroundStyle(.secondary)
    }
}
