import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), unfiledStars, theme(UUID)
}

/// Which face of a theme is showing in the center and right columns.
public enum ThemeFace: String, Sendable { case articles, questions }

/// What the questions face has selected: the theme's "いまの理解" or one question.
public enum ThemeQuestionSelection: Hashable, Sendable { case understanding, question(UUID) }

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var themeFaces: [UUID: ThemeFace] = [:]
    private var questionSelections: [UUID: ThemeQuestionSelection] = [:]
    public init() {}
    public func face(of themeID: UUID) -> ThemeFace { themeFaces[themeID] ?? .articles }
    public func questionSelection(of themeID: UUID) -> ThemeQuestionSelection { questionSelections[themeID] ?? .understanding }
    public mutating func selectQuestion(_ selection: ThemeQuestionSelection, in themeID: UUID) { questionSelections[themeID] = selection }
    /// A theme's questions face is not a reading surface: j/k, the article list and scroll memory do not apply.
    public func isReading(_ scope: ReaderWorkspaceScope) -> Bool {
        if case .theme(let id) = scope { return face(of: id) == .articles }
        return true
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        guard isReading(scope) else { return }
        readers[scope] = state
    }
    /// Leaving the articles face saves the reader first; leaving the questions face never overwrites it.
    public mutating func switchFace(of themeID: UUID, to face: ThemeFace, rememberingReader state: ReaderSelectionState) {
        if self.face(of: themeID) == .articles { readers[.theme(themeID)] = state }
        themeFaces[themeID] = face
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
