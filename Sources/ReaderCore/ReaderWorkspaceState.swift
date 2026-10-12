import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String)
}

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    /// Whether the note is open beside the article. It starts closed. Opening or closing it does not touch the reader (the selected
    /// article and the scroll memory), and it stays as it is when the person goes to another screen.
    public var noteOpen = false
    /// Whether the list of articles is shown beside the open note (the 「一覧」 button): the screen is then the list, the article and the
    /// note. It starts hidden and stays as the person left it while the app runs. It has no effect while the note is closed.
    public var noteListShown = false
    public init() {}
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        readers[scope] = state
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
