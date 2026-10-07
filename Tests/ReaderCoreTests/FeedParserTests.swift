import Foundation
import Testing
@testable import ReaderCore

struct FeedParserTests {
    @Test func bookmarkArticleImageIsNotPublisherIcon() throws {
        let source = URL(string: "https://synthetic.example/rss")!
        let body = "<blockquote><cite><img src='https://synthetic.example/favicon.png'></cite><p><img class='entry-image' src='https://synthetic.example/preview.jpg'></p><p>合成抜粋</p></blockquote>"
        for (metadata, expected) in [("<h:imageurl>https://synthetic.example/photo.jpg</h:imageurl>", "photo.jpg"), ("", "preview.jpg"), ("<x:imageurl>https://synthetic.example/wrong.jpg</x:imageurl>", "preview.jpg")] {
            let xml = "<rss xmlns:h='http://www.hatena.ne.jp/info/xmlns#' xmlns:x='urn:foreign' xmlns:c='http://purl.org/rss/1.0/modules/content/'><channel><title>合成ブックマーク</title><item><guid>a</guid>\(metadata)<c:encoded><![CDATA[\(body)]]></c:encoded></item></channel></rss>"
            let entry = try #require(try FeedParser.parse(Data(xml.utf8), sourceURL: source).entries.first)
            #expect(entry.imageURL?.absoluteString == "https://synthetic.example/" + expected)
        }
        #expect(ImageMetadata.firstHTMLImage("<cite><img src='/favicon.png'></cite><img width='1' height='1' src='/tracker.png'>", base: source) == nil)
    }
    @Test func imageMetadataUsesPriorityAndNodeBase() throws {
        let source = URL(string: "https://synthetic.example/feed/rss")!
        let enclosure = "<enclosure url='../enclosure.jpg' type='image/jpeg'/>"
        let media = "<m:content url='../media.jpg' medium='image'/><m:thumbnail url='../thumb.jpg'/>"
        let body = "<content:encoded xml:base='https://synthetic.example/articles/'><![CDATA[<p>本文<img src='file:///bad'><img src='https://user:pass@bad.example/image'><img src='../image.jpg'></p>]]></content:encoded>"
        for (nodes, expected) in [(enclosure + media + body, "enclosure.jpg"), (media + body, "media.jpg"), ("<m:thumbnail url='../thumb.jpg'/>" + body, "thumb.jpg"), (body, "image.jpg")] {
            let xml = "<rss xmlns:m='http://search.yahoo.com/mrss/' xmlns:content='http://purl.org/rss/1.0/modules/content/'><channel><title>合成</title><link>https://synthetic.example/site/</link><image><url>../icon.png</url></image><item><guid>a</guid><title>A</title>\(nodes)</item></channel></rss>"
            let feed = try FeedParser.parse(Data(xml.utf8), sourceURL: source)
            #expect(feed.entries[0].imageURL?.absoluteString == "https://synthetic.example/" + expected)
            #expect(feed.entries[0].body == "本文")
            #expect(feed.siteURL?.absoluteString == "https://synthetic.example/site/" && feed.iconURL?.absoluteString == "https://synthetic.example/icon.png")
        }
    }
    @Test func atomImagesSupportHTMLXHTMLAndEnclosures() throws {
        let source = URL(string: "https://synthetic.example/feed/atom")!
        for body in ["<content type='html'>&lt;p&gt;本文&lt;img src='../image.jpg'&gt;&lt;/p&gt;</content>", "<content type='xhtml'><div xmlns='http://www.w3.org/1999/xhtml'><p>本文<img src='../image.jpg'/></p></div></content>"] {
            let xml = "<feed xmlns='http://www.w3.org/2005/Atom'><title>合成</title><link href='../site/'/><logo>../logo.png</logo><icon>../icon.png</icon><entry><id>a</id>\(body)</entry></feed>"
            let parsed = try FeedParser.parse(Data(xml.utf8), sourceURL: source)
            #expect(parsed.iconURL?.absoluteString == "https://synthetic.example/icon.png")
            #expect(parsed.siteURL?.absoluteString == "https://synthetic.example/site/")
            #expect(parsed.entries[0].imageURL?.absoluteString == "https://synthetic.example/image.jpg")
            #expect(parsed.entries[0].body == "本文")
        }
        let xml = "<feed xmlns='http://www.w3.org/2005/Atom' xml:base='https://synthetic.example/base/'><entry><id>a</id><link rel='enclosure' type='image/png' href='image.png'/><link rel='alternate' href='article'/></entry></feed>"
        let parsed = try FeedParser.parse(Data(xml.utf8), sourceURL: source)
        #expect(parsed.entries[0].imageURL?.absoluteString == "https://synthetic.example/base/image.png")
        #expect(parsed.entries[0].url?.absoluteString == "https://synthetic.example/base/article")
    }
    @Test @MainActor func expiredArticleImagesDoNotResurrect() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now, url = URL(string: "https://synthetic.example/image-rss")!
        let xml = "<rss><channel><title>合成</title><link>https://synthetic.example/</link><item><guid>a</guid><description>要約</description><enclosure url='https://synthetic.example/image.png' type='image/png'/></item></channel></rss>"
        let parsed = try FeedParser.parse(Data(xml.utf8), sourceURL: url)
        let store = try ReaderStore(url: library.url, now: at)
        let feed = try store.importFeed(parsed, receivedAt: at)
        let article = try #require(store.articles.first)
        #expect(article.imageURL == "https://synthetic.example/image.png")
        #expect(ImageMetadata.favicon(iconURL: feed.iconURL, siteURL: feed.siteURL, sourceURL: feed.sourceURL)?.absoluteString == "https://synthetic.example/favicon.ico")
        let later = at.addingTimeInterval(31 * 86_400)
        try store.purgeExpired(at: later); _ = try store.importFeed(parsed, receivedAt: later)
        #expect(article.imageURL == nil && article.summary.isEmpty)
    }
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
