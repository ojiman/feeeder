import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), theme(UUID)
}

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var openNotes: Set<UUID> = []
    public init() {}
    /// Whether a theme's note is open beside the article. Remembered per theme while the app runs; a theme starts with it closed.
    /// Opening or closing the note does not touch the theme's reader (the selected article and the scroll memory).
    public func isNoteOpen(of themeID: UUID) -> Bool { openNotes.contains(themeID) }
    public mutating func setNote(open: Bool, of themeID: UUID) {
        if open { openNotes.insert(themeID) } else { openNotes.remove(themeID) }
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        readers[scope] = state
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
