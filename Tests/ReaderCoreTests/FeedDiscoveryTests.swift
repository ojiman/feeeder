import Foundation
import Testing
@testable import ReaderCore

/// A site address is accepted too: the feed the page announces is used (decision 0038).
@MainActor struct FeedDiscoveryTests {
    private let page = URL(string: "https://blog.example/")!
    private func find(_ html: String, base: URL? = nil) -> URL? { FeedDiscovery.feedURL(inHTML: Data(html.utf8), baseURL: base ?? page) }

    @Test func theAnnouncedFeedIsFoundAndRelativeAddressesAreResolved() {
        #expect(find(#"<html><head><link rel="alternate" type="application/rss+xml" title="Posts" href="/feed.xml"></head></html>"#)?.absoluteString == "https://blog.example/feed.xml")
        #expect(find(#"<head><link href="atom" type="application/atom+xml" rel="alternate"></head>"#, base: URL(string: "https://blog.example/posts/")!)?.absoluteString == "https://blog.example/posts/atom")
        #expect(find(#"<head><link rel="alternate" type="application/rdf+xml" href="https://cdn.example/rdf"></head>"#)?.absoluteString == "https://cdn.example/rdf")
    }
    @Test func theFirstOfSeveralIsUsedAndOtherLinksAreIgnored() {
        let html = """
        <head><link rel="stylesheet" href="/s.css"><link rel="canonical" href="/">
        <link rel="alternate" type="text/html" hreflang="en" href="/en/">
        <link rel="alternate" type="application/json+oembed" href="/oembed">
        <link rel="alternate" type="application/atom+xml" title="Posts" href="/posts.atom">
        <link rel="alternate" type="application/rss+xml" title="Comments" href="/comments.xml"></head>
        """
        #expect(find(html)?.absoluteString == "https://blog.example/posts.atom")
    }
    @Test func relAndTypeAreReadLikeTheBrowsersDo() {
        #expect(find(#"<head><LINK REL="Alternate Feed" TYPE="Application/RSS+XML" HREF="/f"></head>"#)?.absoluteString == "https://blog.example/f")
        #expect(find(#"<head><link rel="alternate" type="application/rss+xml"></head>"#) == nil)                 // no address
        #expect(find(#"<head><link type="application/rss+xml" href="/f"></head>"#) == nil)                       // not an alternate
    }
    @Test func onlyUsableAddressesAreAccepted() {
        #expect(find(#"<head><link rel="alternate" type="application/rss+xml" href="javascript:alert(1)"></head>"#) == nil)
        #expect(find(#"<head><link rel="alternate" type="application/rss+xml" href="https://name:secret@cdn.example/f"></head>"#) == nil)
        #expect(find(#"<head><link rel="alternate" type="application/rss+xml" href="http://blog.example/f"></head>"#) == nil)   // a secure page never leads to plain http
        #expect(find(#"<head><link rel="alternate" type="application/rss+xml" href="http://blog.example/f"></head>"#, base: URL(string: "http://blog.example/")!) != nil)
    }
    @Test func aPageWithoutAnnouncementHasNone() {
        #expect(find("<html><head><title>Home</title></head><body><a href='/feed'>Feed</a></body></html>") == nil)
        #expect(find("") == nil)
    }

    // MARK: The client

    private func endpoint() -> URL { URL(string: "https://\(UUID().uuidString.lowercased()).example/")! }
    private var client: FeedClient { FeedClient(http: HTTPClient(protocolClasses: [StubURLProtocol.self])) }
    private func html(feed: String?) -> Data {
        Data("<!doctype html><html><head>\(feed.map { #"<link rel="alternate" type="application/rss+xml" href="\#($0)">"# } ?? "")</head><body>home</body></html>".utf8)
    }

    @Test func aSiteAddressLeadsToItsFeedAndRemembersTheSiteAsTheWayItWasFound() async throws {
        let site = endpoint(), feedURL = site.appending(path: "feed.xml")
        StubURLProtocol.register(.init(data: html(feed: "/feed.xml")), at: site)
        StubURLProtocol.register(.init(headers: ["ETag": "v1"], data: Data(FeedParserTests.rss.utf8)), at: feedURL)
        let found = try await client.fetchOrDiscover(url: site)
        #expect(found.parsed.sourceURL == feedURL && found.parsed.title == "合成ニュース")           // the subscription is the feed, not the page
        #expect(found.etag == "v1" && found.foundOnPage == site)
    }
    @Test func aFeedAddressIsUsedAsItIs() async throws {
        let url = endpoint().appending(path: "rss")
        StubURLProtocol.register(.init(data: Data(FeedParserTests.rss.utf8)), at: url)
        let found = try await client.fetchOrDiscover(url: url)
        #expect(found.parsed.sourceURL == url && found.foundOnPage == nil)
    }
    @Test func aPageWithoutAFeedOrWithABadLinkSaysSo() async throws {
        let bare = endpoint()
        StubURLProtocol.register(.init(data: html(feed: nil)), at: bare)
        await #expect(throws: FeedImportError.noFeedInPage) { try await client.fetchOrDiscover(url: bare) }
        let loop = endpoint()                                                                           // the link leads to another page: one step only
        StubURLProtocol.register(.init(data: html(feed: "/again")), at: loop)
        StubURLProtocol.register(.init(data: html(feed: "/again")), at: loop.appending(path: "again"))
        await #expect(throws: FeedImportError.noFeedInPage) { try await client.fetchOrDiscover(url: loop) }
        let broken = endpoint()                                                                         // the link leads to a missing feed: the real reason shows
        StubURLProtocol.register(.init(data: html(feed: "/gone.xml")), at: broken)
        StubURLProtocol.register(.init(status: 404), at: broken.appending(path: "gone.xml"))
        await #expect(throws: HTTPError.self) { try await client.fetchOrDiscover(url: broken) }
    }
    @Test func refreshStillTreatsAPageAsAPage() async {
        let site = endpoint()
        StubURLProtocol.register(.init(data: html(feed: "/feed.xml")), at: site)
        await #expect(throws: FeedImportError.htmlPage) { try await client.fetch(url: site) }          // a saved subscription never jumps to another address
    }
}
