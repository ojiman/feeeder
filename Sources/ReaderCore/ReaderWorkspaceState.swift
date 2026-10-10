import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), unfiledStars, theme(UUID)
}

/// Which face of a theme is showing in the center and right columns.
public enum ThemeFace: String, Sendable { case articles, note }

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var themeFaces: [UUID: ThemeFace] = [:]
    public init() {}
    public func face(of themeID: UUID) -> ThemeFace { themeFaces[themeID] ?? .articles }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        readers[scope] = state
    }
    /// A theme's two faces share one reader (the selected article and the scroll memory), so an article chosen on the note face
    /// is still the one shown after going back to the articles face. Leaving either face saves it.
    public mutating func switchFace(of themeID: UUID, to face: ThemeFace, rememberingReader state: ReaderSelectionState) {
        readers[.theme(themeID)] = state
        themeFaces[themeID] = face
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
