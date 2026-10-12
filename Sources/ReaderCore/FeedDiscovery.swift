import Foundation
import SwiftSoup

/// Finds the feed that a Web page announces with `<link rel="alternate" type="application/rss+xml" href="…">`,
/// so the address of a site can be added as well as the address of its feed (decision 0038).
public enum FeedDiscovery {
    private static let feedTypes: Set<String> = ["application/rss+xml", "application/atom+xml", "application/rdf+xml"]

    /// The first announced feed whose address is usable, or nil. A relative address is resolved against `baseURL`.
    /// A secure page never leads to plain `http://`. Nothing is fetched here.
    public static func feedURL(inHTML data: Data, baseURL: URL) -> URL? {
        guard let document = try? SwiftSoup.parse(String(decoding: data, as: UTF8.self), baseURL.absoluteString),
              let links = try? document.select("link[href]") else { return nil }
        for link in links {
            guard let rel = try? link.attr("rel"), let type = try? link.attr("type"), let href = try? link.attr("href"),
                  rel.lowercased().split(whereSeparator: \.isWhitespace).contains("alternate"),
                  feedTypes.contains(type.trimmingCharacters(in: .whitespaces).lowercased()),
                  !href.trimmingCharacters(in: .whitespaces).isEmpty,
                  let url = ArticleURL.validated(href, relativeTo: baseURL),
                  !(baseURL.scheme?.lowercased() == "https" && url.scheme?.lowercased() == "http") else { continue }
            return url
        }
        return nil
    }
}
