import Foundation
import SwiftData

public enum ThemeError: LocalizedError {
    case missingName, missingTheme, missingArticle, missingQuestionText
    public var errorDescription: String? {
        switch self {
        case .missingName: "テーマの名前を入力してください。"
        case .missingTheme: "テーマが見つかりません。"
        case .missingArticle: "記事が見つかりません。"
        case .missingQuestionText: "問いの文を入力してください。"
        }
    }
}

/// Fixed lenses for starting a question. `draft` is the deterministic fallback; the on-device
/// assistant may later propose a more specific question, but this text must always work.
public enum QuestionLens: String, CaseIterable, Sendable {
    case assumption, exception, condition, tradeoff, personal, custom

    public var title: String {
        switch self {
        case .assumption: "前提を疑う"
        case .exception: "例外・反論"
        case .condition: "成り立つ条件"
        case .tradeoff: "トレードオフ"
        case .personal: "自分の場合"
        case .custom: "自由に書く"
        }
    }
    public func draft(themeName: String) -> String {
        let name = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .assumption: return "「\(name)」は、どんな前提の上に成り立っているか。その前提は本当に正しいか。"
        case .exception: return "「\(name)」に当てはまらない例外や、反対の立場からの反論はあるか。"
        case .condition: return "「\(name)」は、どんな条件のもとで成り立つか。条件が変わると何が変わるか。"
        case .tradeoff: return "「\(name)」で得るものと引き換えに、何を手放しているか。"
        case .personal: return "「\(name)」は、自分の場合どう当てはまるか。何を変え、何を変えないか。"
        case .custom: return ""
        }
    }
}

@Model public final class Theme {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var understanding: String
    public var createdAt: Date
    public var updatedAt: Date
    public init(name: String, at: Date) {
        id = UUID(); self.name = name; understanding = ""; createdAt = at; updatedAt = at
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

@Model public final class ThemeQuestion {
    @Attribute(.unique) public var id: UUID
    public var themeID: UUID
    public var lensRaw: String
    public var text: String
    public var answer: String
    public var evidenceArticleIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date
    public var lens: QuestionLens { QuestionLens(rawValue: lensRaw) ?? .custom }
    public var isAnswered: Bool { !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public init(themeID: UUID, lens: QuestionLens, text: String, at: Date) {
        id = UUID(); self.themeID = themeID; lensRaw = lens.rawValue; self.text = text
        answer = ""; evidenceArticleIDs = []; createdAt = at; updatedAt = at
    }
}

extension ReaderStore {
    public func theme(id: UUID) -> Theme? { themes.first { $0.id == id } }

    @discardableResult public func createTheme(name: String, at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThemeError.missingName }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        try save(); try reload()
        return theme
    }
    public func renameTheme(id: UUID, to name: String, at: Date) throws {
        try reloadIfNeeded()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThemeError.missingName }
        guard let theme = theme(id: id), theme.name != name else { return }
        theme.name = name; theme.updatedAt = at
        try save(); try reload()
    }
    /// Typing path: saves without reloading so the editor is not rebuilt on every change.
    public func saveUnderstanding(themeID: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID), theme.understanding != text else { return }
        theme.understanding = text; theme.updatedAt = at
        try save()
    }
    public func deleteTheme(id: UUID) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: id) else { return }
        for link in themeArticles where link.themeID == id { context.delete(link) }
        for question in themeQuestions where question.themeID == id { context.delete(question) }
        context.delete(theme)
        try save(); try reload()
    }

    @discardableResult public func addArticle(_ articleID: UUID, toTheme themeID: UUID, at: Date) throws -> ThemeArticle {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        guard let article = article(id: articleID) else { throw ThemeError.missingArticle }
        if themeMembers[themeID]?.contains(articleID) == true,
           let existing = themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }) {
            return existing
        }
        let summary = isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let link = ThemeArticle(themeID: themeID, article: article, summary: summary, at: at)
        context.insert(link)
        theme.updatedAt = at
        try save(); try reload()
        return link
    }
    public func removeArticle(_ articleID: UUID, fromTheme themeID: UUID, at: Date) throws {
        try reloadIfNeeded()
        guard let link = themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }) else { return }
        for question in themeQuestions where question.themeID == themeID && question.evidenceArticleIDs.contains(articleID) {
            question.evidenceArticleIDs.removeAll { $0 == articleID }
            question.updatedAt = at
        }
        context.delete(link)
        theme(id: themeID)?.updatedAt = at
        try save(); try reload()
    }

    public func themeArticleIDs(themeID: UUID) -> [UUID] {
        _ = themeArticles
        guard let members = themeMembers[themeID], !members.isEmpty else { return [] }
        return articleIDs.filter { members.contains($0) }
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
    /// Starred articles in no theme. `keeping` keeps the current selection visible after it leaves the inbox.
    public func unfiledStarredArticleIDs(keeping: UUID?) -> [UUID] {
        _ = starCount; _ = themeArticles
        return articleIDs.filter { (starredIDs.contains($0) && articleThemeIDs[$0] == nil) || $0 == keeping }
    }
    public var unfiledStarCount: Int { unfiledStarredArticleIDs(keeping: nil).count }

    @discardableResult public func addQuestion(themeID: UUID, lens: QuestionLens, text: String, at: Date) throws -> ThemeQuestion {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ThemeError.missingQuestionText }
        let question = ThemeQuestion(themeID: themeID, lens: lens, text: text, at: at)
        context.insert(question)
        theme.updatedAt = at
        try save(); try reload()
        return question
    }
    public func questions(themeID: UUID) -> [ThemeQuestion] {
        themeQuestions.filter { $0.themeID == themeID }.sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }
    /// Commit-only: the text is trimmed and blank text throws. Do not call it on every keystroke.
    public func updateQuestion(id: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ThemeError.missingQuestionText }
        guard let question = themeQuestions.first(where: { $0.id == id }), question.text != text else { return }
        question.text = text; question.updatedAt = at
        theme(id: question.themeID)?.updatedAt = at
        try save()
    }
    /// Typing path: saves without reloading. The answer is stored exactly as typed.
    public func saveAnswer(questionID: UUID, answer: String, at: Date) throws {
        try reloadIfNeeded()
        guard let question = themeQuestions.first(where: { $0.id == questionID }), question.answer != answer else { return }
        question.answer = answer; question.updatedAt = at
        theme(id: question.themeID)?.updatedAt = at
        try save()
    }
    public func setEvidence(questionID: UUID, articleIDs: [UUID], at: Date) throws {
        try reloadIfNeeded()
        guard let question = themeQuestions.first(where: { $0.id == questionID }) else { return }
        let members = themeMembers[question.themeID] ?? []
        var seen = Set<UUID>()
        let evidence = articleIDs.filter { members.contains($0) && seen.insert($0).inserted }
        guard evidence != question.evidenceArticleIDs else { return }
        question.evidenceArticleIDs = evidence; question.updatedAt = at
        theme(id: question.themeID)?.updatedAt = at
        try save()
    }
    public func deleteQuestion(id: UUID, at: Date) throws {
        try reloadIfNeeded()
        guard let question = themeQuestions.first(where: { $0.id == id }) else { return }
        theme(id: question.themeID)?.updatedAt = at
        context.delete(question)
        try save(); try reload()
    }
}
