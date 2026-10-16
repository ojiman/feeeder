import Foundation
import SwiftData
import Testing
@testable import ReaderCore

// Checks PRD-17 (specification 7).
/// Specification 3.1.4, list filter: the title and the feed's summary of the articles in the scope, and nothing else.
struct ArticleFilterTests {
    @Test func theTitleOrTheSummaryContainsTheText() {
        #expect(ArticleFilter.matches(title: "Swift 6.4 released", summary: "", query: "swift"))          // case does not count
        #expect(ArticleFilter.matches(title: "Release notes", summary: "Concurrency changes", query: "concurrency"))
        #expect(!ArticleFilter.matches(title: "Release notes", summary: "Concurrency changes", query: "SwiftUI"))
        #expect(ArticleFilter.matches(title: "ｓｗｉｆｔの話", summary: "", query: "Swift"))                // full-width letters
        #expect(ArticleFilter.matches(title: "読書と関心", summary: "", query: "関心"))
        #expect(ArticleFilter.matches(title: "Café", summary: "", query: "cafe"))
    }

    @Test func anEmptyOrBlankTextFiltersNothing() {
        #expect(ArticleFilter.query("") == nil && ArticleFilter.query("  \n") == nil)
        #expect(ArticleFilter.query("  swift ") == "swift")
    }

    @Test func theWholeTextIsLookedForNotEachWord() {
        #expect(ArticleFilter.matches(title: "a swift release", summary: "", query: "swift release"))
        #expect(!ArticleFilter.matches(title: "release of swift", summary: "", query: "swift release"))
    }
}

/// The store side: the filter keeps the order of the scope and reads no article body.
@MainActor struct ArticleFilterStoreTests {
    private func store(_ library: TestLibrary, entries: [(String, String, String)]) throws -> ReaderStore {
        let store = try ReaderStore(url: library.url)
        let parsed = entries.enumerated().map { index, entry in
            ParsedEntry(sourceID: "s\(index)", title: entry.0, url: URL(string: "https://feed.example/\(index)"), summary: entry.1, body: entry.2,
                        coverage: .feedProvided, publishedAt: Date(timeIntervalSince1970: Double(1_000 - index)))
        }
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "https://feed.example/rss")!, entries: parsed, skippedEntries: 0), receivedAt: .now)
        return store
    }

    @Test func theScopeIsNarrowedInItsOwnOrderAndTheBodyIsNotSearched() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try store(library, entries: [("Swift news", "", "x"), ("Other", "about swift", "y"), ("Third", "nothing", "swift in the body only")])
        let all = store.visibleArticleIDs(feedID: nil, unreadOnly: false, keeping: nil)
        let found = store.filteredIDs(all, matching: "SWIFT")
        #expect(found.map { store.article(id: $0)?.title } == ["Swift news", "Other"])
        #expect(store.filteredIDs(all, matching: "") == all)
    }

    @Test func aChangedSummaryIsFoundAfterTheNextRefresh() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try store(library, entries: [("Title", "old words", "")])
        let all = store.visibleArticleIDs(feedID: nil, unreadOnly: false, keeping: nil)
        #expect(store.filteredIDs(all, matching: "old").count == 1)                                  // the cache is filled
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "https://feed.example/rss")!, entries: [
            ParsedEntry(sourceID: "s0", title: "Title", url: URL(string: "https://feed.example/0"), summary: "new words", body: "",
                        coverage: .feedProvided, publishedAt: Date(timeIntervalSince1970: 1_000))
        ], skippedEntries: 0), receivedAt: .now)
        #expect(store.filteredIDs(all, matching: "new").count == 1)                                  // dropped on reload
        #expect(store.filteredIDs(all, matching: "old").isEmpty)
    }

    /// Budget W1 (2.1): typing never waits. 10,000 articles are narrowed in well under a frame once the cache is filled.
    @Test func tenThousandArticlesAreNarrowedQuickly() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let configuration = ModelConfiguration("Reader", schema: ReaderStore.schema, url: library.url, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: ReaderStore.schema, configurations: [configuration])); context.autosaveEnabled = false
        let feed = Feed(title: "合成購読", symbol: "dot.radiowaves.left.and.right"); context.insert(feed)
        for index in 0..<10_000 {
            let article = Article(feedID: feed.id, title: "合成記事 \(index)", summary: "負荷試験のための合成要約です。" + (index % 97 == 0 ? "目印" : ""),
                                  publisher: "synthetic.example", publishedAt: Date(timeIntervalSince1970: Double(index)), receivedAt: .now)
            context.insert(article)
            context.insert(FeedMembership(feedID: feed.id, articleID: article.id, sourceID: String(index)))
        }
        try context.save()
        let store = try ReaderStore(url: library.url)
        let all = store.visibleArticleIDs(feedID: nil, unreadOnly: false, keeping: nil)
        #expect(all.count == 10_000)
        _ = store.filteredIDs(all, matching: "目")                                                 // the first pass fills the cache
        let start = ContinuousClock.now
        let found = store.filteredIDs(all, matching: "目印")
        let elapsed = ContinuousClock.now - start
        print("10,000-article cached filter: \(elapsed)")
        #expect(found.count == (0..<10_000).filter { $0 % 97 == 0 }.count)
        #expect(elapsed < .milliseconds(50), "took \(elapsed)")
    }
}
