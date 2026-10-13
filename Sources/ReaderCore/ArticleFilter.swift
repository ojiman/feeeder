import Foundation

/// The list filter (specification 3.1.4): an article matches when its title or the feed's summary contains the typed text, ignoring
/// case, accents and full-width letters. The whole text is looked for, not each word. Nothing else is searched.
public enum ArticleFilter {
    /// The text to look for, or nil when the field is empty or blank (then nothing is filtered).
    public static func query(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    public static func matches(title: String, summary: String, query: String) -> Bool {
        searchText(title: title, summary: summary).contains(folded(query))
    }
    /// The text that is searched, folded once so that each keystroke is a plain comparison.
    static func searchText(title: String, summary: String) -> String { folded(title + "\n" + summary) }
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

extension ReaderStore {
    /// The articles of `ids` that match the filter text, in the same order; all of them when the text is empty. The searched text is
    /// cached outside observation, so typing does not make a view watch every article (`searchTexts` is dropped on each reload).
    public func filteredIDs(_ ids: [UUID], matching text: String) -> [UUID] {
        guard let query = ArticleFilter.query(text).map(ArticleFilter.folded) else { return ids }
        return ids.filter { id in
            let haystack: String
            if let cached = searchTexts[id] { haystack = cached }
            else if let article = article(id: id) {
                haystack = ArticleFilter.searchText(title: article.title, summary: article.summary)
                searchTexts[id] = haystack
            } else { return false }
            return haystack.contains(query)
        }
    }
}
