import Foundation

/// A cheap check that text taken from a web page is the article and not the page's chrome (breadcrumbs, dates, tags, counters, buttons).
/// A page like that gives many tiny paragraphs: a word, a number, a counter. When most paragraphs are tiny the text is not used, and the
/// feed's own text stays (or, for the AI, the feed's text is used).
public enum ExtractionQuality {
    /// A paragraph shorter than this, or without a single letter, is tiny.
    static let tinyLength = 6

    public static func isArticleText(_ paragraphs: [BodyParagraph]) -> Bool {
        let texts = paragraphs.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !texts.isEmpty else { return false }
        let tiny = texts.filter { $0.count < tinyLength || !$0.contains(where: \.isLetter) }.count
        return tiny * 2 <= texts.count
    }
}
