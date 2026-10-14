import Foundation

/// Which article is shown, and whether the person has started reading it: then a newer body (a feed refresh) waits for them.
public struct ArticleLoadingState: Sendable {
    public private(set) var selectedArticleID: UUID?
    private var interacted = false
    public init() {}
    public var mayReplaceCurrentDisplay: Bool { !interacted }
    public mutating func begin(articleID: UUID) { selectedArticleID = articleID; interacted = false }
    public mutating func recordInteraction(articleID: UUID) { if selectedArticleID == articleID { interacted = true } }
}
