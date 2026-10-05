import Foundation

public struct ArticleLoadingState: Sendable {
    public private(set) var selectedArticleID: UUID?
    private var generation = UUID()
    private var interacted = false
    public init() {}
    public var mayReplaceCurrentDisplay: Bool { !interacted }
    @discardableResult public mutating func begin(articleID: UUID) -> UUID {
        selectedArticleID = articleID; generation = UUID(); interacted = false; return generation
    }
    public func accept(articleID: UUID, generation: UUID) -> Bool { selectedArticleID == articleID && self.generation == generation }
    public mutating func recordInteraction(articleID: UUID) { if selectedArticleID == articleID { interacted = true } }
    public func canReplaceDisplay(articleID: UUID, generation: UUID) -> Bool { accept(articleID: articleID, generation: generation) && !interacted }
}
