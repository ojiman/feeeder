import Foundation

/// The articles of a theme as the reader's top bar shows them, and the end rules for moving between them.
public struct ThemeArticleEntry: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let isCurrent: Bool
    /// False for an article that is shown but has left the theme (it stays visible until another article is chosen).
    public let inTheme: Bool
}

extension ReaderStore {
    /// The theme's articles in the order of the list, plus the shown article if it is no longer in the theme.
    public func themeArticleEntries(themeID: UUID, selection: UUID?) -> [ThemeArticleEntry] {
        let members = Set(themeArticleIDs(themeID: themeID))
        return themeArticleIDs(themeID: themeID, keeping: selection).compactMap { id in
            article(id: id).map { ThemeArticleEntry(id: id, title: $0.title, isCurrent: id == selection, inTheme: members.contains(id)) }
        }
    }
}

public enum ThemeArticleSwitcher {
    /// Previous (-1) and next (+1) are possible when the shown article is not at that end. With nothing shown, both open the first one.
    public static func canMove(_ offset: Int, from selection: UUID?, in ids: [UUID]) -> Bool {
        guard !ids.isEmpty else { return false }
        guard let selection, let index = ids.firstIndex(of: selection) else { return true }
        return ids.indices.contains(index + offset)
    }
}
