import Foundation
import SwiftData

public enum ThemeError: LocalizedError {
    case missingName, missingTheme, missingArticle, missingQuestion, missingQuestionText
    public var errorDescription: String? {
        switch self {
        case .missingName: "テーマの名前を入力してください。"
        case .missingTheme: "テーマが見つかりません。"
        case .missingArticle: "記事が見つかりません。"
        case .missingQuestion: "問いが見つかりません。"
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
    public var summary: String
    public var addedAt: Date
    public init(themeID: UUID, articleID: UUID, summary: String, at: Date) {
        key = themeID.uuidString + ":" + articleID.uuidString
        self.themeID = themeID; self.articleID = articleID; self.summary = summary; addedAt = at
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
}
