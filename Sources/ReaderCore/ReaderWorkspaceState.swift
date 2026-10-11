import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), note(UUID)
}

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var closedNotes: Set<UUID> = []
    public init() {}
    /// Whether a note's panel is open beside the article. A note starts with it open (decision 0019); one the person closed stays
    /// closed while the app runs. Opening or closing the panel does not touch the note's reader (the selected article and the scroll memory).
    public func isNoteOpen(of noteID: UUID) -> Bool { !closedNotes.contains(noteID) }
    public mutating func setNote(open: Bool, of noteID: UUID) {
        if open { closedNotes.remove(noteID) } else { closedNotes.insert(noteID) }
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        readers[scope] = state
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
