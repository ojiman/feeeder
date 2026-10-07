import Foundation

public struct ReaderSelectionState: Sendable {
    public private(set) var selectedArticleID: UUID?
    public private(set) var visibleArticleID: UUID?
    public private(set) var scrollAnchors: [UUID: String] = [:]
    public private(set) var scrollOffsets: [UUID: Double] = [:]
    public var listScrollAnchor: UUID?
    public var listScrollOffset: Double = 0
    public var listFocusRequested = false
    public init() {}
    public mutating func select(_ id: UUID?) { selectedArticleID = id; visibleArticleID = id; listFocusRequested = true }
    public mutating func recordScroll(articleID: UUID, anchor: String, offset: Double) {
        scrollAnchors[articleID] = anchor; scrollOffsets[articleID] = max(0, offset)
    }
    public mutating func returnFromOriginal() { listFocusRequested = true }
}

public enum ReaderShortcutPolicy {
    public static func permits(textInput: Bool, markedText: Bool, sheet: Bool, originalPage: Bool) -> Bool {
        !textInput && !markedText && !sheet && !originalPage
    }
}
