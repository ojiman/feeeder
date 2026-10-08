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
    @discardableResult public mutating func selectionChanged(to articleID: UUID?) -> Bool {
        guard url != nil, self.articleID != articleID else { return false }
        close(); return true
    }
}
