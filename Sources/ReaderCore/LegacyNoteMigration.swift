import Foundation

public struct LegacyNoteMigrationResult: Equatable, Sendable {
    public let themes: Int
    public let questions: Int
}

public enum LegacyNoteMigrationError: LocalizedError {
    case verificationFailed(themeName: String)
    public var errorDescription: String? {
        switch self {
        case .verificationFailed(let name): "テーマ「\(name)」のノートが元の文章をすべて含んでいるか確認できませんでした。元の問いと答えは消していません。"
        }
    }
}

extension ReaderStore {
    /// Moves every theme's understanding, questions, answers and evidence into its note, in one save. Nothing is removed unless every
    /// composed note contains all of its source text. A second call finds nothing to do. `onContentPolicyChanged` runs after questions
    /// were removed, so a review or a managed Claude copy that was built from them is dropped.
    @discardableResult public func migrateLegacyThemeContent(at: Date) throws -> LegacyNoteMigrationResult {
        try migrateLegacyThemeContent(at: at, compose: LegacyNoteText.compose)
    }

    func migrateLegacyThemeContent(at: Date, compose: (String, String, [LegacyNoteText.Question]) -> String) throws -> LegacyNoteMigrationResult {
        try reloadIfNeeded()
        struct Plan { let theme: Theme; let note: String; let questions: [ThemeQuestion] }
        var plans: [Plan] = []
        for theme in themes {
            let questions = self.questions(themeID: theme.id)
            let understanding = theme.understanding
            guard !questions.isEmpty || !understanding.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let legacy = questions.map { question in
                LegacyNoteText.Question(text: question.text, answer: question.answer, evidence: question.evidenceArticleIDs.compactMap { id in
                    themeArticles.first { $0.themeID == theme.id && $0.articleID == id }.map { LegacyNoteText.Evidence(title: $0.title, url: $0.url) }
                })
            }
            let note = compose(theme.note, understanding, legacy)
            // Compose and check everything first: a failure here changes nothing.
            guard LegacyNoteText.containsEverything(note, understanding: understanding, questions: legacy),
                  theme.note.isEmpty || note.contains(theme.note.trimmingCharacters(in: .whitespacesAndNewlines))
            else { throw LegacyNoteMigrationError.verificationFailed(themeName: theme.name) }
            plans.append(Plan(theme: theme, note: note, questions: questions))
        }
        guard !plans.isEmpty else { return LegacyNoteMigrationResult(themes: 0, questions: 0) }
        var removed = 0
        for plan in plans {
            plan.theme.note = plan.note; plan.theme.understanding = ""; plan.theme.updatedAt = at
            for question in plan.questions { context.delete(question); removed += 1 }
        }
        try save()
        defer { if removed > 0 { onContentPolicyChanged?() } }
        try reload()
        return LegacyNoteMigrationResult(themes: plans.count, questions: removed)
    }
}
