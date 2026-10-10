import Foundation
import SwiftData

public enum ThemeError: LocalizedError {
    case missingName, missingTheme, missingArticle
    public var errorDescription: String? {
        switch self {
        case .missingName: "テーマの名前を入力してください。"
        case .missingTheme: "テーマが見つかりません。"
        case .missingArticle: "記事が見つかりません。"
        }
    }
}

@Model public final class Theme {
    @Attribute(.unique) public var id: UUID
    public var name: String
    /// The theme's one note: plain text, `#` lines are headings. Stored exactly as typed; no length limit.
    public var note: String = ""
    public var createdAt: Date
    public var updatedAt: Date
    public init(name: String, at: Date) {
        id = UUID(); self.name = name; createdAt = at; updatedAt = at
    }
}

@Model public final class ThemeArticle {
    @Attribute(.unique) public var key: String
    public var themeID: UUID
    public var articleID: UUID
    /// Title, original URL and RSS summary as they were when the article joined the theme.
    public var title: String
    public var url: String?
    public var summary: String
    public var addedAt: Date
    public init(themeID: UUID, article: Article, summary: String, at: Date) {
        key = themeID.uuidString + ":" + article.id.uuidString
        self.themeID = themeID; articleID = article.id; title = article.title; url = article.originalURL
        self.summary = summary; addedAt = at
    }
}

extension ReaderStore {
    public func theme(id: UUID) -> Theme? { themes.first { $0.id == id } }

    @discardableResult public func createTheme(name: String, at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { throw ThemeError.missingName }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        try save(); try reload()
        return theme
    }
    public func renameTheme(id: UUID, to name: String, at: Date) throws {
        try reloadIfNeeded()
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { throw ThemeError.missingName }
        guard let theme = theme(id: id) else { throw ThemeError.missingTheme }
        guard theme.name != name else { return }
        theme.name = name; theme.updatedAt = at
        try save(); try reload()
    }
    /// The typing path: the note is saved as it is, once per change. An unknown theme is an error, never a silent drop.
    public func saveNote(themeID: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        guard theme.note != text else { return }
        theme.note = text; theme.updatedAt = at
        try save()
    }
    public func deleteTheme(id: UUID) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: id) else { return }
        for link in themeArticles where link.themeID == id { context.delete(link) }
        context.delete(theme)
        try save()
        defer { onContentPolicyChanged?() }
        try reload()
    }

    @discardableResult public func addArticle(_ articleID: UUID, toTheme themeID: UUID, at: Date) throws -> ThemeArticle {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        guard let article = article(id: articleID) else { throw ThemeError.missingArticle }
        if themeMembers[themeID]?.contains(articleID) == true,
           let existing = themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }) {
            return existing
        }
        let summary = recordedSummary(of: article, at: at)
        let link = ThemeArticle(themeID: themeID, article: article, summary: summary, at: at)
        context.insert(link)
        theme.updatedAt = at
        try save(); try reload()
        return link
    }
    public func removeArticle(_ articleID: UUID, fromTheme themeID: UUID, at: Date) throws {
        try reloadIfNeeded()
        guard let link = themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }) else { return }
        context.delete(link)
        theme(id: themeID)?.updatedAt = at
        try save()
        defer { onContentPolicyChanged?() }
        try reload()
    }

    public func themeArticleIDs(themeID: UUID, keeping: UUID? = nil) -> [UUID] {
        _ = themeArticles
        let members = themeMembers[themeID] ?? []
        guard !members.isEmpty || keeping != nil else { return [] }
        return articleIDs.filter { members.contains($0) || $0 == keeping }
    }
    public func isInAnyTheme(articleID: UUID) -> Bool {
        _ = themeArticles
        return articleThemeIDs[articleID] != nil
    }
    @discardableResult public func toggleTheme(_ themeID: UUID, for articleID: UUID, at: Date) throws -> ThemeMembershipChange {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        let name = theme.name
        if themeMembers[themeID]?.contains(articleID) == true {
            try removeArticle(articleID, fromTheme: themeID, at: at)
            return .removed(themeName: name)
        }
        try addArticle(articleID, toTheme: themeID, at: at)
        return .added(themeName: name)
    }
    /// Creates the theme and its first article in one save, so a failure never leaves an empty new theme behind.
    @discardableResult public func createTheme(name: String, adding articleID: UUID, at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { throw ThemeError.missingName }
        guard let article = article(id: articleID) else { throw ThemeError.missingArticle }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        context.insert(ThemeArticle(themeID: theme.id, article: article, summary: recordedSummary(of: article, at: at), at: at))
        try save(); try reload()
        return theme
    }
    /// Creates the theme and all of its articles in one save, so a failure leaves neither an empty theme nor a partial one.
    /// Duplicate IDs collapse (order kept); a missing article rejects the whole request.
    @discardableResult public func createTheme(name: String, adding articleIDs: [UUID], at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = SingleLineText.name(name)
        guard !name.isEmpty else { throw ThemeError.missingName }
        var seen = Set<UUID>()
        let unique = articleIDs.filter { seen.insert($0).inserted }
        let articles = try unique.map { id -> Article in
            guard let article = article(id: id) else { throw ThemeError.missingArticle }
            return article
        }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        for article in articles {
            context.insert(ThemeArticle(themeID: theme.id, article: article, summary: recordedSummary(of: article, at: at), at: at))
        }
        try save(); try reload()
        return theme
    }
    private func recordedSummary(of article: Article, at: Date) -> String {
        isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }
    public func themeArticleCount(themeID: UUID) -> Int {
        _ = themeArticles
        return themeMembers[themeID]?.count ?? 0
    }
    public func themeIDs(containing articleID: UUID) -> [UUID] {
        _ = themeArticles
        guard let ids = articleThemeIDs[articleID] else { return [] }
        return themes.map(\.id).filter { ids.contains($0) }
    }

}

public enum ThemeMembershipChange: Equatable, Sendable {
    case added(themeName: String)
    case removed(themeName: String)
}
