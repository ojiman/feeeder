import Foundation
import Testing
@testable import ReaderCore

struct ArticleMarkupTests {
    static let source = URL(string: "https://synthetic.example/feed")!
    static let html = "<blockquote><cite><a href='/article#section'>合成🙂記事</a></cite><p>本文と<a href='/details?q=1&amp;x=2#top'>詳細はこちら</a>。</p></blockquote><p>通常段落<a href='javascript:alert(1)'>危険リンク</a><script>混入不可</script></p>"
    static func feed() throws -> ParsedFeed {
        try FeedParser.parse(Data("<rss xmlns:c='http://purl.org/rss/1.0/modules/content/'><channel><title>合成</title><item><guid>a</guid><link>https://synthetic.example/article</link><c:encoded><![CDATA[\(html)]]></c:encoded></item></channel></rss>".utf8), sourceURL: source)
    }
    @Test func bookmarkQuotesAndNamedLinksSurviveParsing() throws {
        let entry = try #require(try Self.feed().entries.first)
        let blocks = try #require(entry.bodyParagraphs)
        #expect(blocks.map(\.text).joined(separator: "\n\n") == entry.body)
        let quoted = try #require(blocks.first { $0.text.contains("詳細はこちら") })
        #expect(quoted.quoteDepth == 1)
        let link = try #require(quoted.links.first)
        #expect((quoted.text as NSString).substring(with: NSRange(location: link.location, length: link.length)) == "詳細はこちら")
        #expect(link.url == "https://synthetic.example/details?q=1&x=2#top")
        #expect(blocks.last?.quoteDepth == 0 && blocks.last?.links.isEmpty == true)
        #expect(!entry.body.contains("混入不可"))
        let first = try #require(blocks.first)
        #expect(first.links.first?.length == ("合成🙂記事" as NSString).length)
    }
    @Test func extractedContentPreservesLinksAndQuotesWithoutExecutingHTML() throws {
        let data = Data("<article>\(Self.html)<p>合成記事の本文です。リンク先と引用の関係を保持します。</p></article>".utf8)
        let result = try #require(try ArticleExtractor.extract(html: data, response: HTTPResponse(data: data, finalURL: Self.source, statusCode: 200, headers: [:])))
        #expect(result.bodyParagraphs?.contains { $0.quoteDepth == 1 && !$0.links.isEmpty } == true)
        #expect(result.bodyParagraphs?.map(\.text).joined(separator: "\n\n") == result.text)
    }
    @Test func atomXHTMLRetainsAnchorAndRelativeBase() throws {
        let xml = "<feed xmlns='http://www.w3.org/2005/Atom'><entry><id>a</id><content type='xhtml' xml:base='https://synthetic.example/base/'><div xmlns='http://www.w3.org/1999/xhtml'><blockquote><p>日本語<a href='detail#section'>詳細🙂</a></p></blockquote></div></content></entry></feed>"
        let entry = try #require(try FeedParser.parse(Data(xml.utf8), sourceURL: Self.source).entries.first)
        #expect(entry.bodyParagraphs?.first?.links.first?.url == "https://synthetic.example/base/detail#section")
        #expect(entry.bodyParagraphs?.first?.quoteDepth == 1)
    }
    @Test func codeWithBlankLinesDoesNotShiftFollowingLinks() throws {
        let data = Data("<article><pre>  if true {\n\n    print(1)\n  }</pre><p>本文です。<a href='/detail#section'>詳細はこちら</a>。日本語の合成記事でリンクの位置を確かめます。</p></article>".utf8)
        let result = try #require(try ArticleExtractor.extract(html: data, response: HTTPResponse(data: data, finalURL: Self.source, statusCode: 200, headers: [:])))
        let content = ArticleContent(articleID: UUID(), text: result.text, summary: "", coverage: result.coverage, originalURL: Self.source, bodyParagraphs: result.bodyParagraphs)
        #expect(content.paragraphs == content.bodyParagraphs.map(\.text))
        #expect(content.paragraphs.first?.hasPrefix("  if true") == true)
        #expect(content.bodyParagraphs.last?.links.first?.url == "https://synthetic.example/detail#section")
    }
    @Test func atomXHTMLLineBreakDoesNotDuplicateBeforeLink() throws {
        let xml = "<feed xmlns='http://www.w3.org/2005/Atom'><entry><id>a</id><content type='xhtml'><div xmlns='http://www.w3.org/1999/xhtml'><p>前半<br/><a href='https://synthetic.example/detail'>後半</a></p></div></content></entry></feed>"
        let entry = try #require(try FeedParser.parse(Data(xml.utf8), sourceURL: Self.source).entries.first)
        #expect(entry.body == "前半\n後半")
        #expect(entry.bodyParagraphs?.first?.links.first?.location == 3)
    }
    @Test @MainActor func formattingSurvivesReopenAndExpiresWithBody() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, now: at)
            _ = try store.importFeed(Self.feed(), receivedAt: at)
            return try #require(store.articles.first?.id)
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let content = try #require(try reopened.content(articleID: id, at: at))
        #expect(content.bodyParagraphs.contains { !$0.links.isEmpty && $0.quoteDepth == 1 })
        try reopened.purgeExpired(at: at.addingTimeInterval(31 * 86400))
        #expect(try reopened.content(articleID: id, at: at.addingTimeInterval(31 * 86400)) == nil)
    }
    @Test @MainActor func syntheticReadingLibraryKeepsHistoryDuringRefresh() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let directory = ProcessInfo.processInfo.environment["FEEEDER_POLISH_DEMO_DIRECTORY"].map { URL(fileURLWithPath: $0) } ?? library.directory
        if directory != library.directory {
            try #require(directory.deletingLastPathComponent().path == "/private/tmp" && directory.lastPathComponent.hasPrefix("feeeder-"))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        let at = Date.now, base = "http://127.0.0.1:18889"
        let store = try ReaderStore(url: directory.appending(path: "Reader.store"), now: at)
        #expect(store.feeds.isEmpty)
        for feedNumber in 1...3 {
            let entries = (1...4).map { number in
                let index = (feedNumber - 1) * 4 + number
                let published = number == 1 ? "" : "<pubDate>\(at.addingTimeInterval(number == 2 ? -86400 * 400 : number == 3 ? -86400 : -Double(index * 60)).formatted(.iso8601))</pubDate>"
                let paragraphs = (1...24).map { "<p>合成段落 \($0)：日本語の長い本文を読み、選択とスクロールの維持を確かめます。<a href='\(base)/linked#section'>詳細はこちら</a>。</p>" }.joined()
                return "<item><guid>demo-\(index)</guid><title>合成記事 \(index) — 読書と関心を整理する、日々の情報から次のアイデアを見つけるために</title>\(published)<link>\(base)/article/\(index)</link><h:imageurl>\(base)/photo.png</h:imageurl><description>これは実際の記事ではない合成要約です。公開時刻と長いタイトル、既読・未読の一覧表示を確かめます。</description><c:encoded><![CDATA[<blockquote><cite><img src='\(base)/favicon.png'><a href='\(base)/linked'>合成出典</a></cite><p><img class='entry-image' src='\(base)/photo.png'></p>\(paragraphs)</blockquote><p>引用の外の通常段落。</p>]]></c:encoded></item>"
            }.joined()
            let xml = "<rss xmlns:h='http://www.hatena.ne.jp/info/xmlns#' xmlns:c='http://purl.org/rss/1.0/modules/content/'><channel><title>合成購読 \(feedNumber)</title><image><url>\(base)/favicon.png</url></image>\(entries)</channel></rss>"
            let parsed = try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: base + "/rss/\(feedNumber)")!)
            #expect(parsed.entries.filter { $0.publishedAt != nil }.count == 3)
            let feed = try store.importFeed(parsed, receivedAt: at)
            if feedNumber < 3 { try store.moveFeed(id: feed.id, toFolder: feedNumber == 1 ? "技術" : "暮らし") }
            let article = try #require(store.articles.first { $0.feedID == feed.id })
            try store.markDisplayed(articleID: article.id, at: at)
            let readAt = article.firstReadAt
            _ = try store.importFeed(parsed, receivedAt: at.addingTimeInterval(60))
            #expect(article.firstReadAt == readAt && article.imageURL == base + "/photo.png")
            #expect(try store.content(articleID: article.id, at: at)?.bodyParagraphs.contains { !$0.links.isEmpty && $0.quoteDepth == 1 } == true)
        }
        #expect(store.feeds.count == 3 && store.articles.count == 12)
    }
}
