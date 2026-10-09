import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), unfiledStars, theme(UUID), dailyNotes, weeklyNotes
    public var isReading: Bool {
        switch self { case .dailyNotes, .weeklyNotes: false; default: true }
    }
}

/// Which face of a theme is showing in the center and right columns.
public enum ThemeFace: String, Sendable { case articles, questions }

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    public var dailyNoteID: UUID?
    public var dailyOpened = false
    public var weeklyNoteID: UUID?
    public var weekKey: String
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var themeFaces: [UUID: ThemeFace] = [:]
    public init(at: Date = .now, timeZone: TimeZone = .current) {
        let current = WeekCalendar.range(containing: at, timeZone: timeZone)
        weekKey = WeekCalendar.range(containing: current.start.addingTimeInterval(-1), timeZone: timeZone).startDay
    }
    public func face(of themeID: UUID) -> ThemeFace { themeFaces[themeID] ?? .articles }
    /// A theme's questions face is not a reading surface: j/k, the article list and scroll memory do not apply.
    public func isReading(_ scope: ReaderWorkspaceScope) -> Bool {
        if case .theme(let id) = scope { return face(of: id) == .articles }
        return scope.isReading
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
