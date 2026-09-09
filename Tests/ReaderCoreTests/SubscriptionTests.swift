import Foundation
import Testing
@testable import ReaderCore

@MainActor struct SubscriptionTests {
    @Test func importUpdateDeduplicateAndUnsubscribePreservesLike() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rss-subscriptions-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Reader.store")
        let id: UUID = try autoreleasepool {
            let store = try ReaderStore(url: storeURL)
            let first = try FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://feed.example/a")!)
            let feed = try store.importFeed(first)
            let article = try #require(store.articles.first { $0.originalURL != nil })
            let articleID = article.id
            try store.setRead(article, true)
            try store.toggleLike(article, at: Date(timeIntervalSince1970: 123))
            try store.updateSubscription(feed, title: "自分の名前", folder: "Engineering")
            _ = try store.importFeed(first)
            #expect(store.articles.count == 7)
            #expect(store.feeds.count == 4)
            #expect(feed.title == "自分の名前")
            let second = try FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://aggregator.example/rss")!)
            let other = try store.importFeed(second)
            #expect(store.articles.count == 7)
            #expect(store.isArticle(article, in: feed.id))
            #expect(store.isArticle(article, in: other.id))
            #expect(article.publisher == "publisher.example")
            #expect(article.isRead)
            try store.unsubscribe(feed)
            #expect(!store.isArticle(article, in: feed.id))
            try store.unsubscribe(other)
            #expect(store.articles.contains { $0.id == articleID })
            #expect(store.like(for: article)?.likedAt == Date(timeIntervalSince1970: 123))
            #expect(store.body(for: article)?.contains("本文 & 補足") == true)
            return articleID
        }
        let reopened = try ReaderStore(url: storeURL)
        let article = try #require(reopened.articles.first { $0.id == id })
        #expect(reopened.like(for: article) != nil)
        #expect(reopened.feeds.count == 3)
        #expect(reopened.memberships.filter { $0.articleID == id }.isEmpty)
    }

    @Test func subscriptionEditsSurviveReopenAndMalformedImportDoesNotMutate() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rss-subscriptions-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Reader.store")
        let id = try autoreleasepool {
            let store = try ReaderStore(url: url)
            let feed = try store.importFeed(FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://feed.example/rss")!))
            try store.updateSubscription(feed, title: "変更済み", folder: "技術")
            #expect(throws: (any Error).self) {
                try store.importFeed(FeedParser.parse(Data("<rss>".utf8), sourceURL: URL(string: "https://bad.example/rss")!))
            }
            #expect(store.feeds.count == 4)
            return feed.id
        }
        let reopened = try ReaderStore(url: url)
        let feed = try #require(reopened.feeds.first { $0.id == id })
        #expect(feed.title == "変更済み")
        #expect(feed.folder == "技術")
        #expect(reopened.memberships.count == 7)
    }

    @Test func updateFromSameSourceReplacesBodyAndRetainsMissingLink() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rss-subscriptions-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appending(path: "Reader.store"))
        let source = URL(string: "https://feed.example/rss")!
        _ = try store.importFeed(FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: source))
        let article = try #require(store.articles.first { $0.originalURL != nil })
        let changed = FeedParserTests.rss
            .replacingOccurrences(of: "<link>https://publisher.example/posts/1#top</link>", with: "")
            .replacingOccurrences(of: "<p>本文 &amp; 補足</p><pre>a\n  b</pre>", with: "<p>訂正</p>")
        _ = try store.importFeed(FeedParser.parse(Data(changed.utf8), sourceURL: source))
        #expect(store.articles.count == 7)
        #expect(article.originalURL == "https://publisher.example/posts/1")
        #expect(store.body(for: article) == "訂正")
    }
}
