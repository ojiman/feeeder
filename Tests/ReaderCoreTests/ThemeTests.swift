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
}
