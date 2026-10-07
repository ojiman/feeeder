import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor
struct ReaderStoreTests {
    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rss-reader-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Reader.store")
    }

    @Test func seedingTwiceDoesNotDuplicateArticlesOrFeeds() throws {
        let url = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try ReaderStore(url: url, seedDemo: true)
        let ids = store.articles.map(\.id)
        try store.seedIfEmpty()
        #expect(store.articles.map(\.id) == ids)
        #expect(store.articles.count == 6)
        #expect(store.feeds.count == 3)
    }

    @Test func keyboardSelectionClampsToVisibleList() {
        let ids = [UUID(), UUID(), UUID()]
        #expect(ReaderNavigation.move(nil, by: 1, in: ids) == ids[0])
        #expect(ReaderNavigation.move(ids[0], by: -1, in: ids) == ids[0])
        #expect(ReaderNavigation.move(ids[2], by: 1, in: ids) == ids[2])
        #expect(ReaderNavigation.move(ids[0], by: 1, in: ids) == ids[1])
        #expect(ReaderNavigation.move(nil, by: 1, in: []) == nil)
    }

    @Test func failedSaveCanRetryWithPreviouslySelectedModels() throws {
        let url = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let at = Date(timeIntervalSince1970: 1_000_000)
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)])
        var fail = false
        let store = try ReaderStore(container: container, now: at, saveHook: {
            if fail { throw CocoaError(.fileWriteUnknown) }
        })
        let parsed = try FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
        let feed = try store.importFeed(parsed, receivedAt: at)
        let article = try #require(store.articles.first)
        fail = true
        #expect(throws: (any Error).self) { try store.setRead(article, true) }
        #expect(store.article(id: article.id)?.isRead == false)
        fail = false
        try store.setRead(article, true)
        try store.updateSubscription(feed, title: "再試行した購読", folder: "技術")
        #expect(store.article(id: article.id)?.isRead == true)
        #expect(store.feed(id: feed.id)?.title == "再試行した購読")
        let reopened = try ReaderStore(url: url, now: at)
        #expect(reopened.article(id: article.id)?.isRead == true)
        #expect(reopened.feed(id: feed.id)?.folder == "技術")
        try store.unsubscribe(feed)
        #expect(store.feeds.isEmpty && store.article(id: article.id)?.isRead == true)
    }
}
