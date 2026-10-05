import Foundation
import SwiftSoup

public struct ExtractionResult: Sendable, Equatable {
    public let text: String
    public let coverage: ContentCoverage
    public let sourceURL: URL
    public init(text: String, coverage: ContentCoverage, sourceURL: URL) {
        self.text = text; self.coverage = coverage; self.sourceURL = sourceURL
    }
}

public enum ArticleExtractor {
    public static func extract(html: Data, response: HTTPResponse) throws -> ExtractionResult? {
        guard response.statusCode == 200, html.count <= 5 * 1024 * 1024,
              let decoded = decode(html, contentType: response.headers["content-type"]) else { return nil }
        let document = try SwiftSoup.parse(decoded, response.finalURL.absoluteString)
        guard try document.select("[class*=paywall], [id*=paywall], [class*=captcha], [id*=captcha]").isEmpty() else { return nil }
        let pageText = try document.text().lowercased()
        let restrictions = ["subscribe to continue", "sign in to read", "verify you are human", "ログインして続きを読む", "有料会員限定", "購読して続きを読む"]
        guard !restrictions.contains(where: pageText.contains) else { return nil }
        try document.select("script, style, nav, form, iframe, aside, footer, header, [hidden], [aria-hidden=true], .advertisement, .ads").remove()
        guard let root = try document.select("article").first() ?? document.select("main").first(),
              !(try root.select("p, pre").isEmpty()) else { return nil }
        let text = render(root).replacingOccurrences(of: "\n[ \t]+\n", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A quality floor, not a claim that the complete article was obtained.
        guard text.filter({ $0.isLetter || $0.isNumber }).count >= 25 else { return nil }
        return ExtractionResult(text: text, coverage: .extracted, sourceURL: response.finalURL)
    }
    private static func render(_ node: Node, preformatted: Bool = false, depth: Int = 0) -> String {
        guard depth <= 128 else { return "" }
        if let text = node as? TextNode {
            return preformatted ? text.getWholeText() : text.getWholeText().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }
        guard let element = node as? Element else { return "" }
        let tag = element.tagName().lowercased()
        if tag == "br" { return "\n" }
        let text = element.getChildNodes().map { render($0, preformatted: preformatted || tag == "pre", depth: depth + 1) }.joined()
        if ["p", "pre", "div", "section", "h1", "h2", "h3", "h4", "li", "blockquote", "tr"].contains(tag) {
            return "\n\n" + (tag == "pre" ? text.trimmingCharacters(in: .newlines) : text.trimmingCharacters(in: .whitespacesAndNewlines)) + "\n\n"
        }
        return text
    }
    private static func decode(_ data: Data, contentType: String?) -> String? {
        let scan = String(decoding: data.prefix(8192), as: UTF8.self)
        let declaration = contentType.flatMap(charset) ?? charset(scan)
        let encoding: String.Encoding
        switch declaration?.lowercased() {
        case nil, "utf-8", "utf8": encoding = .utf8
        case "shift_jis", "shift-jis", "sjis", "windows-31j": encoding = .shiftJIS
        case "euc-jp": encoding = .japaneseEUC
        case "iso-8859-1": encoding = .isoLatin1
        case "windows-1252": encoding = .windowsCP1252
        default: return nil
        }
        return String(data: data, encoding: encoding)
    }
    private static func charset(_ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)charset\s*=\s*["']?([a-z0-9_-]+)"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

public struct ArticleFetcher: Sendable {
    private let http: any HTTPFetching
    public init(http: any HTTPFetching = HTTPClient(followsRedirects: false)) { self.http = http }
    public func fetch(url: URL) async -> ExtractionResult? {
        do {
            guard let url = ArticleURL.validated(url.absoluteString), var parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
            parts.path = "/robots.txt"; parts.query = nil; parts.fragment = nil
            guard let robotsURL = parts.url else { return nil }
            let robots = try await http.fetch(url: robotsURL, headers: [:], maximumBytes: 512 * 1024)
            guard robots.finalURL.host == url.host, robots.finalURL.port == url.port, robots.finalURL.scheme == url.scheme else { return nil }
            if robots.statusCode == 200 {
                guard let text = String(data: robots.data, encoding: .utf8), RobotsPolicy.permits(url: url, robotsText: text, userAgent: "Feeeder") else { return nil }
            } else if robots.statusCode != 404 && robots.statusCode != 410 { return nil }
            try Task.checkCancellation()
            let response = try await http.fetch(url: url, headers: ["Accept": "text/html"], maximumBytes: 5 * 1024 * 1024)
            // A redirected resource has not been checked against its robots rules; don't use it.
            guard response.finalURL == url else { return nil }
            return try ArticleExtractor.extract(html: response.data, response: response)
        } catch { return nil }
    }
}
