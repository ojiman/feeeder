import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct ThemeTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    let day: TimeInterval = 86_400

    @Test func lensDraftsAreFixedAndNameTheTheme() {
        for lens in QuestionLens.allCases where lens != .custom {
            let draft = lens.draft(themeName: " 金利と家計 ")
            #expect(draft.contains("「金利と家計」") && draft.hasSuffix("。"))
        }
        #expect(QuestionLens.custom.draft(themeName: "x").isEmpty)
        #expect(Set(QuestionLens.allCases.map(\.title)).count == QuestionLens.allCases.count)
    }

    @Test func createTrimsNameAndRejectsBlank() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "  LLMの実用設計  ", at: at)
        #expect(theme.name == "LLMの実用設計" && theme.understanding.isEmpty)
        #expect(store.themes.map(\.id) == [theme.id] && store.theme(id: theme.id)?.id == theme.id)
        #expect(throws: ThemeError.self) { try store.createTheme(name: "   \n", at: at) }
        #expect(store.themes.count == 1)
    }

    @Test func renameAndUnderstandingPersistAcrossReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let theme = try store.createTheme(name: "金利", at: at)
            try store.renameTheme(id: theme.id, to: " 金利と家計 ", at: at.addingTimeInterval(10))
            try store.saveUnderstanding(themeID: theme.id, text: "いまの理解", at: at.addingTimeInterval(20))
            #expect(throws: ThemeError.self) { try store.renameTheme(id: theme.id, to: " ", at: at) }
            #expect(store.theme(id: theme.id)?.name == "金利と家計")
            return theme.id
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let theme = try #require(reopened.theme(id: id))
        #expect(theme.name == "金利と家計" && theme.understanding == "いまの理解")
        #expect(theme.createdAt == at && theme.updatedAt == at.addingTimeInterval(20))
    }

    @Test func unknownThemeIsANoOp() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let missing = UUID()
        try store.renameTheme(id: missing, to: "存在しない", at: at)
        try store.saveUnderstanding(themeID: missing, text: "書けない", at: at)
        try store.deleteTheme(id: missing)
        #expect(store.themes.isEmpty)
    }

    @Test func addingSnapshotsSummaryAndRepeatKeepsTheRecord() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let theme = try store.createTheme(name: "A", at: at)
        let first = try store.addArticle(article.id, toTheme: theme.id, at: at)
        article.summary = "更新後の要約"
        let repeated = try store.addArticle(article.id, toTheme: theme.id, at: at.addingTimeInterval(30))
        #expect(first.key == repeated.key && store.themeArticles.count == 1)
        #expect(repeated.summary == "合成RSS要約" && repeated.addedAt == at)
        #expect(store.themeArticleIDs(themeID: theme.id) == [article.id])
        #expect(store.themeArticleCount(themeID: theme.id) == 1)
    }

    @Test func missingOrExpiredSummaryStoresAnEmptySummary() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = ""
        let theme = try store.createTheme(name: "A", at: at)
        let empty = try store.addArticle(article.id, toTheme: theme.id, at: at)
        #expect(empty.summary.isEmpty)
        let other = store.articles[1]
        let expired = try store.addArticle(other.id, toTheme: theme.id, at: at.addingTimeInterval(31 * day))
        #expect(expired.summary.isEmpty && store.article(id: other.id)?.title == other.title)
    }

    @Test func recordSurvivesExpiryUnsubscribeAndReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        article.originalURL = "https://synthetic.example/article"
        let (id, title, url) = (article.id, article.title, article.originalURL)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(id, toTheme: theme.id, at: at)
        let later = at.addingTimeInterval(31 * day)
        try store.purgeExpired(at: later)
        for feed in store.feeds { try store.unsubscribe(feed) }
        #expect(store.article(id: id)?.summary.isEmpty == true)
        let reopened = try ReaderStore(url: library.url, now: later)
        let link = try #require(reopened.themeArticles.first)
        #expect(link.summary == "合成RSS要約" && link.articleID == id)
        #expect(link.title == title && link.url == url)
        #expect(reopened.article(id: id)?.title == title && reopened.article(id: id)?.originalURL == url)
    }

    @Test func starAndThemeAreIndependent() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let a = store.articles[0], b = store.articles[1]
        try store.setStar(articleID: a.id, isStarred: true, at: at)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(a.id, toTheme: theme.id, at: at)
        try store.addArticle(b.id, toTheme: theme.id, at: at)
        #expect(a.starredAt == at && b.starredAt == nil)
        #expect(a.firstReadAt == nil && b.firstReadAt == nil && !a.isRead && !b.isRead)
        try store.setStar(articleID: a.id, isStarred: false, at: at)
        #expect(Set(store.themeArticleIDs(themeID: theme.id)) == [a.id, b.id])
        #expect(store.themeIDs(containing: a.id) == [theme.id])
    }

    @Test func unfiledStarsAreStarredArticlesInNoTheme() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(3) { try store.setStar(articleID: id, isStarred: true, at: at) }
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == Array(ids.prefix(3)) && store.unfiledStarCount == 3)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == [ids[1], ids[2]])
        try store.setStar(articleID: ids[1], isStarred: false, at: at)
        #expect(store.unfiledStarredArticleIDs(keeping: ids[1]) == [ids[1], ids[2]])
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == [ids[2]])
        try store.removeArticle(ids[0], fromTheme: theme.id, at: at)
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == [ids[0], ids[2]])
    }

    @Test func oneArticleCanBelongToSeveralThemes() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let first = try store.createTheme(name: "A", at: at)
        let second = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        try store.addArticle(article.id, toTheme: second.id, at: at)
        try store.addArticle(article.id, toTheme: first.id, at: at)
        #expect(store.themeIDs(containing: article.id) == [first.id, second.id])
        try store.removeArticle(article.id, fromTheme: first.id, at: at)
        #expect(store.themeIDs(containing: article.id) == [second.id])
        try store.removeArticle(article.id, fromTheme: first.id, at: at)
        #expect(store.themeArticleCount(themeID: first.id) == 0 && store.themeArticleCount(themeID: second.id) == 1)
    }

    @Test func unknownIDsThrowWithoutChangingData() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "A", at: at)
        #expect(throws: ThemeError.self) { try store.addArticle(UUID(), toTheme: theme.id, at: at) }
        #expect(throws: ThemeError.self) { try store.addArticle(store.articles[0].id, toTheme: UUID(), at: at) }
        #expect(store.themeArticles.isEmpty)
    }

    @Test func questionsKeepAnswersAndDeriveTheAnsweredState() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "A", at: at)
        let draft = QuestionLens.assumption.draft(themeName: "A")
        let question = try store.addQuestion(themeID: theme.id, lens: .assumption, text: " \(draft) ", at: at)
        #expect(question.lens == .assumption && question.text == draft && !question.isAnswered)
        try store.saveAnswer(questionID: question.id, answer: "自分の答え", at: at.addingTimeInterval(5))
        #expect(question.isAnswered && question.updatedAt == at.addingTimeInterval(5))
        try store.saveAnswer(questionID: question.id, answer: "  \n", at: at.addingTimeInterval(6))
        #expect(!question.isAnswered)
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: theme.id, lens: .custom, text: "  ", at: at) }
        let second = try store.addQuestion(themeID: theme.id, lens: .custom, text: "自分で立てた問い", at: at.addingTimeInterval(1))
        #expect(store.questions(themeID: theme.id).map(\.id) == [question.id, second.id])
        try store.updateQuestion(id: second.id, text: " 言い換えた問い ", at: at.addingTimeInterval(2))
        #expect(second.text == "言い換えた問い")
        #expect(throws: ThemeError.self) { try store.updateQuestion(id: second.id, text: " ", at: at) }
        #expect(second.text == "言い換えた問い")
        try store.deleteQuestion(id: second.id, at: at)
        #expect(store.questions(themeID: theme.id).map(\.id) == [question.id])
    }

    @Test func unknownThemeOrQuestionIsRejectedOrIgnored() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: UUID(), lens: .custom, text: "問い", at: at) }
        try store.saveAnswer(questionID: UUID(), answer: "書けない", at: at)
        try store.setEvidence(questionID: UUID(), articleIDs: [], at: at)
        try store.deleteQuestion(id: UUID(), at: at)
        #expect(store.themeQuestions.isEmpty)
    }

    @Test func evidenceMustBeThemeMembersAndRemovingAnArticleKeepsTheAnswer() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let a = store.articles[0], b = store.articles[1], outsider = store.articles[2]
            let theme = try store.createTheme(name: "A", at: at)
            try store.addArticle(a.id, toTheme: theme.id, at: at)
            try store.addArticle(b.id, toTheme: theme.id, at: at)
            let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
            try store.setEvidence(questionID: question.id, articleIDs: [b.id, outsider.id, a.id, b.id], at: at)
            #expect(question.evidenceArticleIDs == [b.id, a.id])
            try store.saveAnswer(questionID: question.id, answer: "答え", at: at)
            try store.removeArticle(b.id, fromTheme: theme.id, at: at.addingTimeInterval(5))
            #expect(question.evidenceArticleIDs == [a.id] && question.answer == "答え")
            return question.id
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let question = try #require(reopened.themeQuestions.first { $0.id == id })
        #expect(question.evidenceArticleIDs.count == 1 && question.answer == "答え")
    }

    @Test func deletingAThemeRemovesOnlyItsOwnRecords() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let first = try store.createTheme(name: "A", at: at)
        let second = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        for theme in [first, second] {
            try store.addArticle(article.id, toTheme: theme.id, at: at)
            try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
        }
        try store.deleteTheme(id: first.id)
        #expect(store.themes.map(\.id) == [second.id])
        #expect(store.themeArticles.map(\.themeID) == [second.id] && store.themeQuestions.map(\.themeID) == [second.id])
        #expect(store.article(id: article.id)?.starredAt == at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.themes.map(\.id) == [second.id] && reopened.themeQuestions.count == 1)
    }

    final class SaveGate { var failNext = false }

    private func gatedStore(_ library: TestLibrary, _ gate: SaveGate) throws -> ReaderStore {
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        return try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if gate.failNext { gate.failNext = false; throw CocoaError(.fileWriteUnknown) }
        })
    }

    @Test func failedSaveLeavesNoPartialThemeStateAndCanBeRetried() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let ids = store.articles.map(\.id)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失敗", at: at) }
        #expect(store.themes.isEmpty)
        let theme = try store.createTheme(name: "成功", at: at)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.addArticle(ids[0], toTheme: theme.id, at: at) }
        #expect(store.themeArticles.isEmpty && store.themeArticleCount(themeID: theme.id) == 0)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        try store.addArticle(ids[1], toTheme: theme.id, at: at)

        let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
        try store.setEvidence(questionID: question.id, articleIDs: [ids[0], ids[1]], at: at)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveAnswer(questionID: question.id, answer: "失われる答え", at: at) }
        #expect(store.themeQuestions.first { $0.id == question.id }?.answer == "")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveUnderstanding(themeID: theme.id, text: "失われる理解", at: at) }
        #expect(store.theme(id: theme.id)?.understanding == "")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.setEvidence(questionID: question.id, articleIDs: [ids[0]], at: at) }
        #expect(store.themeQuestions.first { $0.id == question.id }?.evidenceArticleIDs == [ids[0], ids[1]])
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.renameTheme(id: theme.id, to: "失われる名前", at: at) }
        #expect(store.theme(id: theme.id)?.name == "成功")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.addQuestion(themeID: theme.id, lens: .custom, text: "失われる問い", at: at) }
        #expect(store.questions(themeID: theme.id).count == 1)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.addQuestion(themeID: theme.id, lens: .assumption, at: at) }
        #expect(store.questions(themeID: theme.id).count == 1)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.updateQuestion(id: question.id, text: "失われる文", at: at) }
        #expect(store.themeQuestions.first { $0.id == question.id }?.text == "問い")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.deleteQuestion(id: question.id, at: at) }
        #expect(store.questions(themeID: theme.id).count == 1)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.removeArticle(ids[1], fromTheme: theme.id, at: at) }
        #expect(store.themeArticleCount(themeID: theme.id) == 2)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.deleteTheme(id: theme.id) }
        #expect(store.themes.count == 1 && store.themeArticles.count == 2 && store.themeQuestions.count == 1)

        try store.saveAnswer(questionID: question.id, answer: "再試行した答え", at: at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.themeQuestions.first?.answer == "再試行した答え" && reopened.themeArticles.count == 2)
    }

    @Test func everythingSurvivesAReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let (themeID, questionID, articleID) = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let article = store.articles[0]; article.summary = "合成RSS要約"
            let theme = try store.createTheme(name: "A", at: at)
            try store.saveUnderstanding(themeID: theme.id, text: "いまの理解", at: at)
            try store.addArticle(article.id, toTheme: theme.id, at: at)
            let question = try store.addQuestion(themeID: theme.id, lens: .tradeoff, text: "問い", at: at)
            try store.saveAnswer(questionID: question.id, answer: "答え", at: at)
            try store.setEvidence(questionID: question.id, articleIDs: [article.id], at: at)
            return (theme.id, question.id, article.id)
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.theme(id: themeID)?.understanding == "いまの理解")
        let link = try #require(reopened.themeArticles.first)
        #expect(link.articleID == articleID && link.summary == "合成RSS要約")
        let question = try #require(reopened.themeQuestions.first { $0.id == questionID })
        #expect(question.lens == .tradeoff && question.answer == "答え" && question.evidenceArticleIDs == [articleID])
        #expect(reopened.themeArticleIDs(themeID: themeID) == [articleID])
    }

    final class RecoveryGate { var failSave = false, failReload = false }

    /// Once reloading works again, the very first theme change must recover the store and succeed.
    /// `save()` alone refuses while a reload is pending, so only a leading `reloadIfNeeded()` passes this.
    @Test func eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = RecoveryGate()
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        let store = try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if gate.failSave { throw CocoaError(.fileWriteUnknown) }
        }, reloadHook: {
            if gate.failReload { throw CocoaError(.fileReadUnknown) }
        })
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "元の名前", at: at)
        let (themeID, firstQuestionID) = (theme.id, try store.addQuestion(themeID: theme.id, lens: .custom, text: "元の問い", at: at).id)
        try store.addArticle(ids[0], toTheme: themeID, at: at)
        try store.addArticle(ids[1], toTheme: themeID, at: at)
        try store.setEvidence(questionID: firstQuestionID, articleIDs: [ids[0], ids[1]], at: at)

        func induceFailedRecovery() {
            gate.failSave = true; gate.failReload = true
            #expect(throws: (any Error).self) { try store.createTheme(name: "誘発", at: at) }
            gate.failSave = false; gate.failReload = false
        }
        func question() -> ThemeQuestion? { store.themeQuestions.first { $0.id == firstQuestionID } }

        induceFailedRecovery()
        try store.renameTheme(id: themeID, to: "新しい名前", at: at)
        #expect(store.theme(id: themeID)?.name == "新しい名前")
        induceFailedRecovery()
        try store.saveUnderstanding(themeID: themeID, text: "新しい理解", at: at)
        #expect(store.theme(id: themeID)?.understanding == "新しい理解")
        induceFailedRecovery()
        try store.addArticle(ids[2], toTheme: themeID, at: at)
        #expect(store.themeArticleCount(themeID: themeID) == 3)
        induceFailedRecovery()
        try store.addQuestion(themeID: themeID, lens: .condition, text: "二つ目の問い", at: at.addingTimeInterval(1))
        #expect(store.questions(themeID: themeID).count == 2)
        // A rename that fails together with its recovery must not leak its unsaved name into a lens draft.
        gate.failSave = true; gate.failReload = true
        #expect(throws: (any Error).self) { try store.renameTheme(id: themeID, to: "保存されなかった名前", at: at) }
        gate.failSave = false; gate.failReload = false
        let drafted = try store.addQuestion(themeID: themeID, lens: .assumption, at: at.addingTimeInterval(2))
        #expect(drafted.text.contains("「新しい名前」") && !drafted.text.contains("保存されなかった名前") && store.questions(themeID: themeID).count == 3)
        induceFailedRecovery()
        try store.deleteQuestion(id: drafted.id, at: at)
        induceFailedRecovery()
        try store.updateQuestion(id: firstQuestionID, text: "新しい問い", at: at)
        #expect(question()?.text == "新しい問い")
        induceFailedRecovery()
        try store.saveAnswer(questionID: firstQuestionID, answer: "新しい答え", at: at)
        #expect(question()?.answer == "新しい答え")
        induceFailedRecovery()
        try store.setEvidence(questionID: firstQuestionID, articleIDs: [ids[0]], at: at)
        #expect(question()?.evidenceArticleIDs == [ids[0]])
        induceFailedRecovery()
        try store.removeArticle(ids[0], fromTheme: themeID, at: at)
        #expect(store.themeArticleCount(themeID: themeID) == 2 && question()?.evidenceArticleIDs.isEmpty == true)
        induceFailedRecovery()
        try store.deleteQuestion(id: firstQuestionID, at: at)
        #expect(store.questions(themeID: themeID).count == 1)
        induceFailedRecovery()
        try store.deleteTheme(id: themeID)
        #expect(store.theme(id: themeID) == nil && store.themeArticles.isEmpty && store.themeQuestions.isEmpty)
        induceFailedRecovery()
        try store.createTheme(name: "回復後の新規", at: at)
        #expect(store.themes.map(\.name) == ["回復後の新規"])
    }

    @Test func recordKeepsTheTitleAndURLFromTheTimeOfAdding() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        article.title = "追加時のタイトル"; article.originalURL = "https://synthetic.example/a"
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
        #expect(link.title == "追加時のタイトル" && link.url == "https://synthetic.example/a")
        article.title = "再取得で変わったタイトル"; article.originalURL = "https://synthetic.example/b"
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let repeated = try store.addArticle(article.id, toTheme: theme.id, at: at.addingTimeInterval(5))
        #expect(repeated.title == "追加時のタイトル" && repeated.url == "https://synthetic.example/a")
        let reopened = try ReaderStore(url: library.url, now: at)
        let kept = try #require(reopened.themeArticles.first)
        #expect(kept.title == "追加時のタイトル" && kept.url == "https://synthetic.example/a")
    }

    @Test func anyChangeInsideAThemeBumpsItsUpdatedAt() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let theme = try store.createTheme(name: "A", at: at)
        func updatedAt() -> Date? { store.theme(id: theme.id)?.updatedAt }
        func later(_ seconds: Double) -> Date { at.addingTimeInterval(seconds) }
        try store.addArticle(article.id, toTheme: theme.id, at: later(1)); #expect(updatedAt() == later(1))
        let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: later(2)); #expect(updatedAt() == later(2))
        try store.updateQuestion(id: question.id, text: "言い換えた問い", at: later(3)); #expect(updatedAt() == later(3))
        try store.saveAnswer(questionID: question.id, answer: "答え", at: later(4)); #expect(updatedAt() == later(4))
        try store.setEvidence(questionID: question.id, articleIDs: [article.id], at: later(5)); #expect(updatedAt() == later(5))
        try store.removeArticle(article.id, fromTheme: theme.id, at: later(6)); #expect(updatedAt() == later(6))
        try store.deleteQuestion(id: question.id, at: later(7)); #expect(updatedAt() == later(7))
        try store.deleteQuestion(id: question.id, at: later(8)); #expect(updatedAt() == later(7))
    }

    @Test func equalTimestampsKeepADeterministicOrder() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let ids = store.articles.map(\.id)
            for index in 0..<8 {
                let theme = try store.createTheme(name: "T\(index)", at: at)
                for id in ids.prefix(3) { try store.addArticle(id, toTheme: theme.id, at: at) }
                for _ in 0..<2 { try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at) }
            }
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let themeOrder = reopened.themes.map(\.id.uuidString)
        #expect(themeOrder == themeOrder.sorted())
        let linkOrder = reopened.themeArticles.map { "\($0.addedAt.timeIntervalSince1970)|\($0.key)" }
        #expect(linkOrder == linkOrder.sorted())
        let questionOrder = reopened.themeQuestions.map { "\($0.createdAt.timeIntervalSince1970)|\($0.id.uuidString)" }
        #expect(questionOrder == questionOrder.sorted())
    }

    @Test func themeListKeepsTheSelectedArticleUntilItMoves() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        try store.addArticle(ids[2], toTheme: theme.id, at: at)
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: nil) == [ids[0], ids[2]])
        try store.removeArticle(ids[0], fromTheme: theme.id, at: at)
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: ids[0]) == [ids[0], ids[2]])
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: nil) == [ids[2]])
        #expect(store.themeArticleIDs(themeID: theme.id) == [ids[2]])
    }

    @Test func isInAnyThemeFollowsMembership() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        #expect(!store.isInAnyTheme(articleID: id))
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(id, toTheme: theme.id, at: at)
        #expect(store.isInAnyTheme(articleID: id))
        try store.removeArticle(id, fromTheme: theme.id, at: at)
        #expect(!store.isInAnyTheme(articleID: id))
    }

    @Test func toggleAddsThenRemovesAndNamesTheTheme() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        let theme = try store.createTheme(name: "金利", at: at)
        #expect(try store.toggleTheme(theme.id, for: id, at: at) == .added(themeName: "金利"))
        #expect(store.isInAnyTheme(articleID: id))
        #expect(try store.toggleTheme(theme.id, for: id, at: at) == .removed(themeName: "金利"))
        #expect(!store.isInAnyTheme(articleID: id))
        #expect(throws: ThemeError.self) { try store.toggleTheme(UUID(), for: id, at: at) }
    }

    @Test func creatingWithAnArticleIsOneAtomicSave() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let id = store.articles[0].id
        let expectedSummary = store.articles[0].summary.trimmingCharacters(in: .whitespacesAndNewlines)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失敗", adding: id, at: at) }
        #expect(store.themes.isEmpty && store.themeArticles.isEmpty)
        let theme = try store.createTheme(name: "  成功  ", adding: id, at: at)
        #expect(theme.name == "成功" && store.themeIDs(containing: id) == [theme.id])
        #expect(!expectedSummary.isEmpty && store.themeArticles.first?.summary == expectedSummary)
        #expect(throws: ThemeError.self) { try store.createTheme(name: " ", adding: id, at: at) }
        #expect(throws: ThemeError.self) { try store.createTheme(name: "存在しない", adding: UUID(), at: at) }
        #expect(store.themes.count == 1)
    }

    @Test func lensQuestionUsesTheThemeNameAndRejectsTheFreeLens() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "金利と家計", at: at)
        for lens in QuestionLens.allCases where lens != .custom {
            let question = try store.addQuestion(themeID: theme.id, lens: lens, at: at.addingTimeInterval(1))
            #expect(question.lens == lens && question.text == lens.draft(themeName: "金利と家計") && !question.isAnswered)
            #expect(question.text.contains("「金利と家計」"))
        }
        #expect(store.questions(themeID: theme.id).count == 5)
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: theme.id, lens: .custom, at: at) }
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: UUID(), lens: .assumption, at: at) }
        try store.renameTheme(id: theme.id, to: "改名後", at: at)
        let renamed = try store.addQuestion(themeID: theme.id, lens: .condition, at: at.addingTimeInterval(2))
        #expect(renamed.text.contains("「改名後」"))
    }
}
