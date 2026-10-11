import Foundation

/// A cheap check that text taken from a web page is the article and not the page's chrome (breadcrumbs, dates, tags, counters, buttons).
/// A page that is only chrome gives few letters in many tiny paragraphs: a word, a number, a counter. Such a page is not used, and the
/// feed's own text stays (or, for the AI, the feed's text is used). A page with plenty of text is used even when it has many short
/// headings and list items: the real text is not thrown away with the chrome. Short lists with little else (release notes of a few
/// words, a recipe's ingredients) are not taken; they can still be read in the original page.
public enum ExtractionQuality {
    /// A paragraph shorter than this, or without a single letter, is tiny.
    static let tinyLength = 6
    /// A page with at least this many letters in all is a page with content.
    static let plentyOfText = 400

    public static func isArticleText(_ paragraphs: [BodyParagraph]) -> Bool {
        let texts = paragraphs.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !texts.isEmpty else { return false }
        let tiny = texts.filter { $0.count < tinyLength || !$0.contains(where: \.isLetter) }.count
        if texts.joined().filter(\.isLetter).count >= plentyOfText { return true }
        return tiny * 2 <= texts.count
    }
}
