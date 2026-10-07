import Foundation
import SwiftSoup

public enum ImageMetadata {
    static func firstHTMLImage(_ html: String, base: URL) -> URL? {
        guard let document = try? SwiftSoup.parse(html), let images = try? document.select("img[src]") else { return nil }
        let candidates = images.array().sorted { $0.hasClass("entry-image") && !$1.hasClass("entry-image") }
        for image in candidates {
            if image.parents().array().contains(where: { $0.tagName().lowercased() == "cite" }) { continue }
            let src = (try? image.attr("src")) ?? ""
            if src.lowercased().contains("favicon") || src.contains("/entry/image/") || src.contains("/images/append.gif") { continue }
            if let width = try? image.attr("width"), let height = try? image.attr("height"),
               let w = Int(width), let h = Int(height), w <= 32 && h <= 32 { continue }
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
