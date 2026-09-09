import Foundation
import Testing
@testable import ReaderCore

struct FeedParserTests {
    static let rss = """
    <rss version="2.0" xmlns:body="http://purl.org/rss/1.0/modules/content/">
    <channel><title>合成ニュース</title><item><guid>one</guid><title>A &amp; B</title>
    <link>https://publisher.example/posts/1#top</link><pubDate>Wed, 09 Sep 2026 10:00:00 +0900</pubDate>
    <description>概要</description><body:encoded><![CDATA[<p>本文 &amp; 補足</p><pre>a\n  b</pre>]]></body:encoded>
    </item></channel></rss>
    """
    @Test func rssContentNamespaceAndDate() throws {
        let feed = try FeedParser.parse(Data(Self.rss.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
        #expect(feed.title == "合成ニュース")
        let article = try #require(feed.entries.first)
        #expect(article.title == "A & B")
        #expect(article.url?.absoluteString == "https://publisher.example/posts/1")
        #expect(article.body.contains("本文 & 補足"))
        #expect(article.body.contains("a\n  b"))
        #expect(article.publishedAt == ISO8601DateFormatter().date(from: "2026-09-09T01:00:00Z"))
    }
    @Test func rdfAndDublinCore() throws {
        let xml = """
        <r:RDF xmlns:r="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:d="http://purl.org/dc/elements/1.1/">
        <channel r:about="https://feed.example/rss"><title>RDF合成</title></channel>
        <item r:about="https://publisher.example/2"><title>RDF記事</title><link>https://publisher.example/2</link><d:date>2026-09-09T10:00:00+09:00</d:date><description>本文</description></item></r:RDF>
        """
        let result = try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
        #expect(result.title == "RDF合成")
        #expect(result.entries.count == 1)
        #expect(result.entries.first?.publishedAt == ISO8601DateFormatter().date(from: "2026-09-09T01:00:00Z"))
    }
    @Test func atomResolvesBaseAndIgnoresSelfAndForeignTitle() throws {
        let xml = """
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:foreign" xml:base="https://publisher.example/blog/">
        <title>Atom合成</title><entry xml:base="posts/"><id>tag:example,2026:3</id><title>正しい題</title><x:title>混入不可</x:title>
        <link rel="self" href="api/3"/><link rel="alternate" href="3"/><updated>2026-09-09T01:00:00.123Z</updated>
        <content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p>段落1</p><p>段落2</p></div></content>
        </entry></feed>
        """
        let result = try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://feed.example/atom")!)
        #expect(result.entries.first?.title == "正しい題")
        #expect(result.entries.first?.url?.absoluteString == "https://publisher.example/blog/posts/3")
        #expect(result.entries.first?.publishedAt != nil)
        #expect(result.entries.first?.body.contains("段落1\n") == true)
    }
    @Test func rejectsMalformedAndEntityDocuments() {
        for xml in ["<rss><channel>", "<html><title>not a feed</title></html>",
                    "<!DOCTYPE rss [<!ENTITY x 'expanded'>]><rss><channel><title>&x;</title></channel></rss>"] {
            #expect(throws: (any Error).self) {
                try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
            }
        }
    }
    @Test func rejectsUnsafeURLAndDoesNotInventDates() throws {
        let xml = "<rss><channel><title>合成</title><item><guid>x</guid><title>X</title><link>javascript:alert(1)</link><pubDate>invalid</pubDate><description>x</description></item></channel></rss>"
        let result = try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
        #expect(result.entries.first?.url == nil)
        #expect(result.entries.first?.publishedAt == nil)
        #expect(ArticleURL.validated("file:///etc/passwd") == nil)
        #expect(ArticleURL.validated("https://user:secret@example.com") == nil)
        #expect(ArticleURL.validated("", relativeTo: URL(string: "https://feed.example/rss")) == nil)
    }
    @Test func rdfIdentityUsesNamespaceRatherThanLiteralPrefix() throws {
        let xml = """
        <r:RDF xmlns:r="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/">
        <channel r:about="https://feed.example/rss"><title>合成</title></channel>
        <item r:about="https://publisher.example/identity"><title>リンク要素なし</title><description>本文</description></item></r:RDF>
        """
        let result = try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
        #expect(result.entries.count == 1)
        #expect(result.entries.first?.url?.absoluteString == "https://publisher.example/identity")
    }
    @Test func atomPlainTextPreservesLiteralAngleBrackets() throws {
        let xml = "<feed xmlns='http://www.w3.org/2005/Atom'><title>List&lt;T&gt;</title><entry><id>one</id><title>List&lt;T&gt;</title><content type='text'>型は List&lt;T&gt; です。</content></entry></feed>"
        let parsed = try FeedParser.parse(Data(xml.utf8), sourceURL: URL(string: "https://feed.example/atom")!)
        #expect(parsed.title == "List<T>")
        #expect(parsed.entries.first?.title == "List<T>")
        #expect(parsed.entries.first?.body == "型は List<T> です。")
    }
}
