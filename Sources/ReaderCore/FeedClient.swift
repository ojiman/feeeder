import Foundation

public enum FeedFetchResult: Sendable {
    case modified(ParsedFeed, etag: String?, lastModified: String?)
    case notModified
}

/// A feed that was fetched for a new subscription.
public struct FeedFetchOutcome: Sendable {
    public let parsed: ParsedFeed
    public let etag: String?
    public let lastModified: String?
    /// The Web page whose announced feed this is; nil when the address was the feed itself.
    public let foundOnPage: URL?
}

public struct FeedClient: Sendable {
    private let http: any HTTPFetching
    public init(http: any HTTPFetching = HTTPClient()) { self.http = http }

    public func fetch(url: URL, etag: String? = nil, lastModified: String? = nil) async throws -> FeedFetchResult {
        let response = try await load(url: url, etag: etag, lastModified: lastModified)
        if response.statusCode == 304 { return .notModified }
        return .modified(try parse(response, requestedURL: url), etag: response.headers["etag"], lastModified: response.headers["last-modified"])
    }

    /// For a new subscription: an address that is a Web page, not a feed, leads to the feed the page announces
    /// (one step: the announced address is read as a feed and is never searched again). A saved subscription is never
    /// redirected this way, so `fetch` does not do it.
    public func fetchOrDiscover(url: URL) async throws -> FeedFetchOutcome {
        let response = try await load(url: url, etag: nil, lastModified: nil)
        do {
            return FeedFetchOutcome(parsed: try parse(response, requestedURL: url), etag: response.headers["etag"],
                                    lastModified: response.headers["last-modified"], foundOnPage: nil)
        } catch FeedImportError.htmlPage {
            guard let feedURL = FeedDiscovery.feedURL(inHTML: response.data, baseURL: response.finalURL) else { throw FeedImportError.noFeedInPage }
            do {
                guard case .modified(let parsed, let etag, let modified) = try await fetch(url: feedURL) else { throw HTTPError.invalidResponse }
                return FeedFetchOutcome(parsed: parsed, etag: etag, lastModified: modified, foundOnPage: url)
            } catch FeedImportError.htmlPage { throw FeedImportError.noFeedInPage }
        }
    }

    private func load(url: URL, etag: String?, lastModified: String?) async throws -> HTTPResponse {
        var headers = ["Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml"]
        if let etag { headers["If-None-Match"] = etag }
        if let lastModified { headers["If-Modified-Since"] = lastModified }
        return try await http.fetch(url: url, headers: headers, maximumBytes: 2 * 1024 * 1024)
    }

    private func parse(_ response: HTTPResponse, requestedURL: URL) throws -> ParsedFeed {
        guard response.statusCode == 200 else { throw HTTPError.status(response.statusCode) }
        return try FeedParser.parse(response.data, sourceURL: requestedURL, baseURL: response.finalURL)
    }
}
