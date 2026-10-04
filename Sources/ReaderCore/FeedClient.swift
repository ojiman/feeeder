import Foundation

public enum FeedFetchResult: Sendable {
    case modified(ParsedFeed, etag: String?, lastModified: String?)
    case notModified
}
public struct FeedClient: Sendable {
    private let http: any HTTPFetching
    public init(http: any HTTPFetching = HTTPClient()) { self.http = http }
    public func fetch(url: URL, etag: String? = nil, lastModified: String? = nil) async throws -> FeedFetchResult {
        var headers = ["Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml"]
        if let etag { headers["If-None-Match"] = etag }
        if let lastModified { headers["If-Modified-Since"] = lastModified }
        let response = try await http.fetch(url: url, headers: headers, maximumBytes: 2 * 1024 * 1024)
        if response.statusCode == 304 { return .notModified }
        guard response.statusCode == 200 else { throw HTTPError.status(response.statusCode) }
        return .modified(try FeedParser.parse(response.data, sourceURL: url, baseURL: response.finalURL),
                         etag: response.headers["etag"], lastModified: response.headers["last-modified"])
    }
}
