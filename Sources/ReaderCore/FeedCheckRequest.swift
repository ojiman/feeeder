import Foundation

/// What the add-subscription sheet asks the network (or the parser) about, decided from the text the person typed.
public enum FeedCheckRequest: Sendable, Equatable {
    /// Fetch the address.
    case url(URL)
    /// Parse pasted XML; nothing is fetched. The address names the subscription.
    case xml(Data, URL)

    private static let schemeHint = "http:// か https:// で始まるURLを入れてください。"

    /// The request for what is typed now, or nil while the text cannot be used yet.
    /// While typing, an address is sent only when its host looks complete (see `looksComplete`).
    /// When the person pressed Return (`asked`), any valid address is used, such as `https://localhost/feed`.
    public static func make(source: String, xml: String, manual: Bool, asked: Bool = false) -> FeedCheckRequest? {
        guard let url = ArticleURL.validated(source), asked || looksComplete(url) else { return nil }
        if manual {
            return xml.allSatisfy(\.isWhitespace) ? nil : .xml(Data(xml.utf8), url)
        }
        return .url(url)
    }

    /// A host that looks finished: a name of dotted parts that ends in a part with at least two characters and a letter
    /// (`example.com`, `example.co.uk`, `xn--p1ai`), or a whole IPv4 address (four numbers). It cannot know that
    /// `example.co` is not the start of `example.com`; the pause before the check is the only guard against that.
    private static func looksComplete(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }
        if labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) { return labels.count == 4 }
        guard let last = labels.last else { return false }
        return last.count >= 2 && last.contains(where: \.isLetter)
    }

    /// A short help for text that cannot be used. While typing it speaks only when the text can never become an
    /// address (no `http://`); after Return it also names the reason for a text that looks like an address.
    public static func hint(source: String, asked: Bool = false) -> String? {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            guard asked else { return nil }
            if URLComponents(string: text)?.user != nil { return FeedImportError.invalidURL.localizedDescription }
            return "URLを最後まで入れてください。"
        }
        if !asked, "http://".hasPrefix(lower) || "https://".hasPrefix(lower) { return nil }      // still typing the scheme
        return schemeHint
    }

    /// How long to wait after an edit before checking: typing waits for a pause, a paste (the text grows by more
    /// than one character at once) does not.
    public static func delay(from old: String, to new: String) -> Duration {
        new.count - old.count > 1 ? .milliseconds(50) : .milliseconds(800)
    }
}
