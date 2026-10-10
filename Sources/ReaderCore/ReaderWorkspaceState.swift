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
    /// A theme's note face is not a reading surface: j/k, the article list and scroll memory do not apply.
    public func isReading(_ scope: ReaderWorkspaceScope) -> Bool {
        if case .theme(let id) = scope { return face(of: id) == .articles }
        return true
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        guard isReading(scope) else { return }
        readers[scope] = state
    }
    /// Leaving the articles face saves the reader first; leaving the note face never overwrites it.
    public mutating func switchFace(of themeID: UUID, to face: ThemeFace, rememberingReader state: ReaderSelectionState) {
        if self.face(of: themeID) == .articles { readers[.theme(themeID)] = state }
        themeFaces[themeID] = face
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
