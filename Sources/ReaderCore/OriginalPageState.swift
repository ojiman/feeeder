import Foundation

public struct OriginalPageState {
    public private(set) var articleID: UUID?
    public private(set) var url: URL?
    public init() {}
    @discardableResult public mutating func open(articleID: UUID, url: String) -> Bool {
        guard let target = ArticleURL.validated(url) else { return false }
        self.articleID = articleID; self.url = target
        return true
    }
    public mutating func close() { articleID = nil; url = nil }
    /// Whether selecting this article takes the person out of the page (it is open for another article). Does not close it:
    /// the window slides the page out first and then closes it.
    public func closesWhenSelecting(_ articleID: UUID?) -> Bool { url != nil && self.articleID != articleID }
    @discardableResult public mutating func selectionChanged(to articleID: UUID?) -> Bool {
        guard closesWhenSelecting(articleID) else { return false }
        close(); return true
    }
}
