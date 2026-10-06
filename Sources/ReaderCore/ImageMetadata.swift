import Foundation
import SwiftSoup

public enum ImageMetadata {
    static func firstHTMLImage(_ html: String, base: URL) -> URL? {
        guard let document = try? SwiftSoup.parse(html), let images = try? document.select("img[src]") else { return nil }
        for image in images.array() {
            if let value = try? image.attr("src"), let url = ArticleURL.validated(value, relativeTo: base) { return url }
        }
        return nil
    }
    public static func favicon(iconURL: String?, siteURL: String?, sourceURL: String?) -> URL? {
        if let iconURL, let url = ArticleURL.validated(iconURL) { return url }
        guard let base = (siteURL.flatMap { ArticleURL.validated($0) } ?? sourceURL.flatMap { ArticleURL.validated($0) }),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        parts.path = "/favicon.ico"; parts.query = nil; parts.fragment = nil
        return parts.url
    }
}
