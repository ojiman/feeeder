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
    /// Whether the window-level `Esc` closes the note: always, except when the keyboard is inside the original page, which has its own `Esc`
    /// (a field of the page keeps it). This holds with the original page open too, so the note is never left without a key (decision 0050).
    public static func escapeClosesNote(noteOpen: Bool, keyboardInOriginalPage: Bool) -> Bool {
        noteOpen && !keyboardInOriginalPage
    }
}
