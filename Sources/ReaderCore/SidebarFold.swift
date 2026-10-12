import Foundation

/// When the left panel (the sidebar) is folded away (decisions 0046 and 0047, after Reeder).
public enum SidebarFold {
    /// The fold, and the slide of the original page that goes with it, are one move of this many seconds.
    public static let motionDuration: Double = 0.3

    /// The sidebar is folded while the original page is open and on the note screen, whatever the width of the window. Closing the page
    /// on the note screen must not bring it back.
    public static func folded(pageOpen: Bool, noteScreen: Bool) -> Bool {
        pageOpen || noteScreen
    }
}

/// Where the ✕ on the note screen goes back to: the screen the person was on before the notes (decision 0047). Going from one note to
/// another keeps that place; a note shown at the start has none, and the default is all articles.
public struct NoteScreenReturn: Equatable, Sendable {
    private var before: ReaderWorkspaceScope?
    public init() {}

    public var target: ReaderWorkspaceScope { before ?? .all }

    public mutating func scopeChanged(from old: ReaderWorkspaceScope?, to new: ReaderWorkspaceScope?) {
        guard case .note = new else { before = nil; return }
        if case .note = old { return }
        if let old { before = old }
    }
}
