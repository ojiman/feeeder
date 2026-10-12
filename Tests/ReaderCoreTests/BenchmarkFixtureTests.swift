import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct BenchmarkFixtureTests {
    @Test func largeLibraryIndexesAndReadCountsStayConsistent() throws {
        let library = try TestLibrary()
        let destination = ProcessInfo.processInfo.environment["UNAGI_READER_BENCHMARK_DIRECTORY"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        // Routine regression uses less data; an explicit output directory keeps the full dogfooding fixture.
        let articleCount = destination == nil ? 1_000 : 10_000
        defer { library.cleanup() }
        let directory = destination ?? library.directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = ReaderStore.schema
        let url = directory.appending(path: "Reader.store")
        let configuration = ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container); context.autosaveEnabled = false
        #expect(try context.fetchCount(FetchDescriptor<Article>()) == 0)
        let now = Date.now
        let imageBase = ProcessInfo.processInfo.environment["UNAGI_READER_BENCHMARK_IMAGE_BASE"].flatMap(URL.init(string:))
        let originalBase = ProcessInfo.processInfo.environment["UNAGI_READER_BENCHMARK_ORIGINAL_BASE"].flatMap(URL.init(string:))
        let feeds = (0..<100).map { Feed(title: String(format: "合成購読 %03d", $0), symbol: "dot.radiowaves.left.and.right") }
        for feed in feeds {
            feed.iconURL = imageBase?.appending(path: "favicon.png").absoluteString
            context.insert(feed)
        }
        let text = (1...80).map { "合成段落 \($0)。日本語の長い本文と読書位置を検証します。これは現実の記事ではありません。" }.joined(separator: "\n\n")
        let formatted = text.components(separatedBy: "\n\n").enumerated().map { index, text in
            BodyParagraph(text: text, links: [BodyLink(location: 0, length: 4, url: "http://127.0.0.1:18889/linked#section")], quoteDepth: index < 20 ? 1 : 0)
        }
        for index in 0..<articleCount {
            let feed = feeds[index % 100]
            let article = Article(feedID: feed.id, title: String(format: "合成記事 %05d", index), summary: "負荷試験のための合成要約です。", publisher: "synthetic.example", publishedAt: now.addingTimeInterval(-Double(index)), receivedAt: now)
            article.originalURL = originalBase?.appending(path: "\(index)").absoluteString ?? "http://127.0.0.1:18888/posts/extracted"
            article.imageURL = imageBase?.appending(path: "\(index).png").absoluteString
            context.insert(article)
            context.insert(ContentSnapshot(articleID: article.id, text: text, coverage: .extracted, bodyParagraphs: formatted))
            context.insert(FeedMembership(feedID: feed.id, articleID: article.id, sourceID: String(index)))
        }
        try context.save()
        let store = try ReaderStore(container: container, now: now)
        let articlesPerFeed = articleCount / feeds.count
        #expect(store.articles.count == articleCount && store.feeds.count == 100 && store.unreadCount == articleCount)
        #expect(store.visibleArticleIDs(feedID: feeds[0].id, unreadOnly: false, keeping: nil).count == articlesPerFeed)
        let article = try #require(store.articles.first)
        try store.markDisplayed(articleID: article.id, at: now)
        #expect(store.visibleArticleIDs(feedID: nil, unreadOnly: true, keeping: article.id).count == articleCount)
        #expect(store.visibleArticleIDs(feedID: nil, unreadOnly: true, keeping: nil).count == articleCount - 1)
        #expect(store.unreadCount == articleCount - 1 && store.feedUnreadCounts[article.feedID] == articlesPerFeed - 1)
        #expect(try store.content(articleID: article.id, at: now)?.text == text)
        #expect(try store.content(articleID: article.id, at: now)?.bodyParagraphs == formatted)
    }
}
