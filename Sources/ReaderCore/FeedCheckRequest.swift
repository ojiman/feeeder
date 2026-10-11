import Foundation

/// What the add-subscription sheet asks the network (or the parser) about, decided from the text the person typed.
public enum FeedCheckRequest: Sendable, Equatable {
    /// Fetch the address.
    case url(URL)
    /// Parse pasted XML; nothing is fetched. The address names the subscription.
    case xml(Data, URL)

    /// The request for what is typed now, or nil while the text cannot be an address yet.
    /// A half-typed address is never sent: the host must be complete (a dot, then at least two letters).
    public static func make(source: String, xml: String, manual: Bool) -> FeedCheckRequest? {
        guard let url = ArticleURL.validated(source), let host = url.host,
              let top = host.split(separator: ".", omittingEmptySubsequences: false).last, host.contains("."), top.count >= 2 else { return nil }
        if manual {
            return xml.allSatisfy(\.isWhitespace) ? nil : .xml(Data(xml.utf8), url)
        }
        return .url(url)
    }

    /// A short help for text that can never become an address, such as one without `http://`.
    public static func hint(source: String) -> String? {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains("://") else { return nil }
        return "http:// か https:// で始まるURLを入れてください。"
    }

    /// How long to wait after an edit before checking: typing waits for a pause, a paste does not.
    public static func delay(from old: String, to new: String) -> Duration {
        new.count - old.count > 1 ? .milliseconds(50) : .milliseconds(800)
    }
}
