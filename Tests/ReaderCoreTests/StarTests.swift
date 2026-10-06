import Foundation
import Testing
@testable import ReaderCore

@MainActor struct StarTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    @Test func togglePreservesReadDatesAndExpiry() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = try #require(store.articles.first)
        try store.markDisplayed(articleID: article.id, at: at)
        let received = article.firstReceivedAt
        let expiry = try store.availableContentExpiries(at: at)[article.id]
        try store.setStar(articleID: article.id, isStarred: true, at: at.addingTimeInterval(10))
        #expect(article.starredAt == at.addingTimeInterval(10))
        try store.setStar(articleID: article.id, isStarred: true, at: at.addingTimeInterval(20))
        #expect(article.starredAt == at.addingTimeInterval(10))
        try store.setStar(articleID: article.id, isStarred: false, at: at.addingTimeInterval(30))
        #expect(article.starredAt == nil)
        try store.setStar(articleID: article.id, isStarred: true, at: at.addingTimeInterval(40))
        #expect(article.starredAt == at.addingTimeInterval(40))
        #expect(article.firstReadAt == at && article.firstReceivedAt == received)
        #expect(try store.availableContentExpiries(at: at)[article.id] == expiry)
        let later = at.addingTimeInterval(31 * 86_400)
        try store.purgeExpired(at: later)
        #expect(article.summary.isEmpty && article.starredAt == at.addingTimeInterval(40))
        let reopened = try ReaderStore(url: library.url, now: later)
        #expect(reopened.article(id: article.id)?.starredAt == at.addingTimeInterval(40))
    }
    @Test func keepsUnstarredSelectionUntilMove() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let first = store.articles[0], second = store.articles[1]
        try store.setStar(articleID: first.id, isStarred: true, at: at)
        try store.setStar(articleID: second.id, isStarred: true, at: at)
        try store.setStar(articleID: first.id, isStarred: false, at: at)
        #expect(store.starredArticleIDs(keeping: first.id) == [first.id, second.id])
        #expect(store.starredArticleIDs(keeping: nil) == [second.id])
    }
    @Test func reimportDoesNotEraseStarOrExtendRetention() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, now: at)
        let parsed = try FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://synthetic.example/rss")!)
        _ = try store.importFeed(parsed, receivedAt: at)
        let article = try #require(store.articles.first)
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        _ = try store.importFeed(parsed, receivedAt: at.addingTimeInterval(31 * 86_400))
        #expect(article.starredAt == at && article.summary.isEmpty && article.firstReceivedAt == at)
    }
}
