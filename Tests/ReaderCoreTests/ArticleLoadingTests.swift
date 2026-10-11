import Foundation
import Testing
@testable import ReaderCore

@MainActor struct ArticleLoadingTests {
    @Test func explicitRefreshUpdatesPreviouslyExtractedPlainText() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let xml = "<rss><channel><item><guid>a</guid><link>https://synthetic.example/posts/1</link><description>合成要約</description></item></channel></rss>"
        _ = try store.importFeed(FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://synthetic.example/rss")!))
        let article = try #require(store.articles.first)
        try store.saveExtractedContent(articleID: article.id, result: ExtractionResult(text: "以前の抽出本文", coverage: .extracted, sourceURL: ArticleExtractorTests.url), at: .now)
        let http = ExtractionHTTP(mode: "ok")
        let loading = ArticleLoadingController(store: store, fetcher: ArticleFetcher(http: http))
        await loading.load(articleID: article.id)
        #expect(await http.count == 0 && loading.displayed?.text == "以前の抽出本文")
        await loading.load(articleID: article.id, refresh: true)
        #expect(await http.count == 2 && loading.displayed?.text.contains("最初の段落") == true)
        #expect(article.firstReadAt == nil)
    }
    @Test func failedExplicitRefreshRetainsSavedBodyAndExplainsFailure() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        _ = try store.importFeed(ArticleMarkupTests.feed())
        let article = try #require(store.articles.first)
        let before = try store.content(articleID: article.id, at: .now)
        let loading = ArticleLoadingController(store: store, fetcher: ArticleFetcher(http: ExtractionHTTP(mode: "deny")))
        await loading.load(articleID: article.id, refresh: true)
        #expect(loading.displayed == before)
        #expect(loading.error?.contains("保存済み本文") == true && !loading.loading)
        #expect(article.firstReadAt == nil)
    }
    @Test func lateExtractionDoesNotReplaceSelectedArticle() throws {
        var state = ArticleLoadingState()
        let a = UUID(), b = UUID()
        let old = state.begin(articleID: a)
        let current = state.begin(articleID: b)
        #expect(!state.accept(articleID: a, generation: old))
        #expect(state.accept(articleID: b, generation: current))
        #expect(state.selectedArticleID == b)
        let other = state.begin(articleID: b)
        #expect(!state.accept(articleID: b, generation: current))
        #expect(state.accept(articleID: b, generation: other))
    }
    @Test func lateExtractionPreservesSummaryReadingPosition() {
        var state = ArticleLoadingState(); let id = UUID()
        let generation = state.begin(articleID: id)
        #expect(state.accept(articleID: id, generation: generation) && state.mayReplaceCurrentDisplay)
        state.recordInteraction(articleID: id)
        #expect(!(state.accept(articleID: id, generation: generation) && state.mayReplaceCurrentDisplay))
    }
    @Test func expiredOrDeletedContentCannotBeRestoredByLateResponse() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now
        let store = try ReaderStore(url: library.url, now: now)
        let xml = "<rss><channel><title>合成</title><item><guid>a</guid><link>https://synthetic.example/posts/1</link><description>RSS要約だけです。</description></item></channel></rss>"
        _ = try store.importFeed(FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://synthetic.example/rss")!), receivedAt: now)
        let article = try #require(store.articles.first)
        #expect(try store.content(articleID: article.id, at: now)?.coverage == .summaryOnly)
        let result = ExtractionResult(text: "遅延した合成の抽出本文", coverage: .extracted, sourceURL: ArticleExtractorTests.url)
        try store.saveExtractedContent(articleID: article.id, result: result, at: now.addingTimeInterval(31 * 86400))
        #expect(try store.content(articleID: article.id, at: now.addingTimeInterval(31 * 86400)) == nil)
        #expect(article.firstReadAt == nil)
        try store.deleteContent(articleIDs: [article.id], at: now)
        try store.saveExtractedContent(articleID: article.id, result: result, at: now)
        #expect(try store.content(articleID: article.id, at: now) == nil)
    }
    @Test func deniedRobotsAndHTTPFailuresStopWithoutBypass() async throws {
        for mode in ["deny", "timeout", "401", "403"] {
            let http = ExtractionHTTP(mode: mode)
            let result = await ArticleFetcher(http: http).fetch(url: ArticleExtractorTests.url)
            #expect(result == nil)
            #expect(await http.count == (mode == "deny" || mode == "timeout" ? 1 : 2))
        }
    }
    @Test func discardingAutomaticallyExtractedBodiesKeepsTheFeedTextAndTheSummary() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let xml = "<rss><channel><title>合成</title><item><guid>a</guid><link>https://synthetic.example/posts/a</link><description>Aの要約</description></item><item><guid>b</guid><link>https://synthetic.example/posts/b</link><description>Bの要約</description><content:encoded xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">Bのフィード本文です。</content:encoded></item></channel></rss>"
        _ = try store.importFeed(FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://synthetic.example/rss")!))
        let a = try #require(store.articles.first { $0.originalURL?.hasSuffix("/a") == true })
        let b = try #require(store.articles.first { $0.originalURL?.hasSuffix("/b") == true })
        try store.saveExtractedContent(articleID: a.id, result: ExtractionResult(text: "トップ\n\n27\n\n以前に自動で抽出した本文", coverage: .extracted, sourceURL: ArticleExtractorTests.url), at: .now)
        #expect(try store.content(articleID: a.id, at: .now)?.coverage == .extracted)
        #expect(try store.discardExtractedBodies() == 1)                                         // only a's
        #expect(try store.content(articleID: a.id, at: .now)?.text == "Aの要約")                 // back to what the feed said
        #expect(try store.content(articleID: a.id, at: .now)?.coverage == .summaryOnly)
        #expect(try store.content(articleID: b.id, at: .now)?.coverage == .feedProvided)         // the feed's own body is not touched
        #expect(try store.discardExtractedBodies() == 0)
    }
    @Test func openingAnArticleShowsTheFeedTextAndNeverFetchesThePage() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        _ = try store.importFeed(ArticleMarkupTests.feed())
        let article = try #require(store.articles.first)
        let http = ExtractionHTTP(mode: "ok")
        let loading = ArticleLoadingController(store: store, fetcher: ArticleFetcher(http: http))
        await loading.load(articleID: article.id)
        #expect(await http.count == 0)                                                          // RSS first: no request, nothing waits
        #expect(loading.displayed?.coverage == .feedProvided && !loading.loading)
    }
    @Test func noRSSBodyCanBeExtractedWithoutRecordingRead() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let xml = "<rss><channel><title>合成</title><item><guid>a</guid><link>https://synthetic.example/posts/1</link></item></channel></rss>"
        _ = try store.importFeed(FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://synthetic.example/rss")!))
        let article = try #require(store.articles.first)
        let loading = ArticleLoadingController(store: store, fetcher: ArticleFetcher(http: ExtractionHTTP(mode: "ok")))
        await loading.load(articleID: article.id)
        #expect(loading.displayed?.coverage == .summaryOnly || loading.displayed == nil)        // on opening, only what the feed gave
        await loading.load(articleID: article.id, refresh: true)                                // the full text only when it is asked for
        #expect(loading.displayed?.coverage == .extracted)
        #expect(article.firstReadAt == nil)
    }
    @Test(.timeLimit(.minutes(1))) func controllerDisplaysBWhenAResponseArrivesLate() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        let xml = "<rss><channel><title>合成</title><item><guid>a</guid><link>https://synthetic.example/posts/a</link><description>A要約</description></item><item><guid>b</guid><link>https://synthetic.example/posts/b</link><description>B要約</description></item></channel></rss>"
        _ = try store.importFeed(FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://synthetic.example/rss")!))
        let a = try #require(store.articles.first { $0.originalURL?.hasSuffix("/a") == true })
        let b = try #require(store.articles.first { $0.originalURL?.hasSuffix("/b") == true })
        let gate = ArticleGate()
        let loading = ArticleLoadingController(store: store, fetcher: ArticleFetcher(http: gate))
        let first = Task { await loading.load(articleID: a.id, refresh: true) }
        while !(await gate.isWaiting("/posts/a")) { await Task.yield() }
        let second = Task { await loading.load(articleID: b.id, refresh: true) }
        while !(await gate.isWaiting("/posts/b")) { await Task.yield() }
        loading.recordInteraction(articleID: b.id)
        await gate.release("/posts/a"); await first.value
        #expect(loading.displayed?.articleID == b.id && loading.displayed?.text == "B要約")
        #expect(a.firstReadAt == nil)
        await gate.release("/posts/b"); await second.value
        #expect(loading.displayed?.text == "B要約")
        #expect(loading.availableUpdate?.coverage == .extracted)
        try loading.applyAvailableUpdate()
        #expect(loading.displayed?.articleID == b.id && loading.displayed?.coverage == .extracted)
        #expect(b.firstReadAt == nil) // Fetching and choosing content do not claim actual display.
    }
}

private actor ArticleGate: HTTPFetching {
    var pending: [String: CheckedContinuation<HTTPResponse, any Error>] = [:]
    func isWaiting(_ path: String) -> Bool { pending[path] != nil }
    func fetch(url: URL, headers: [String: String], maximumBytes: Int) async throws -> HTTPResponse {
        if url.path == "/robots.txt" { return HTTPResponse(data: Data("User-agent: *\nAllow: /".utf8), finalURL: url, statusCode: 200, headers: [:]) }
        return try await withCheckedThrowingContinuation { pending[url.path] = $0 }
    }
    func release(_ path: String) {
        pending.removeValue(forKey: path)?.resume(returning: HTTPResponse(data: Data(ArticleExtractorTests.html.utf8), finalURL: URL(string: "https://synthetic.example" + path)!, statusCode: 200, headers: [:]))
    }
}

private actor ExtractionHTTP: HTTPFetching {
    let mode: String
    var count = 0
    init(mode: String) { self.mode = mode }
    func fetch(url: URL, headers: [String: String], maximumBytes: Int) async throws -> HTTPResponse {
        count += 1
        if mode == "timeout" { throw URLError(.timedOut) }
        let robots = url.path == "/robots.txt"
        let data = robots ? Data("User-agent: *\nDisallow: \(mode == "deny" ? "/" : "")\n".utf8) : Data(ArticleExtractorTests.html.utf8)
        return HTTPResponse(data: data, finalURL: url, statusCode: robots ? 200 : Int(mode) ?? 200, headers: [:])
    }

}
