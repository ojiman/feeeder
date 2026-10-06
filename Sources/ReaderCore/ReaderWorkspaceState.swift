import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), dailyNotes, weeklyNotes
    public var isReading: Bool {
        switch self { case .dailyNotes, .weeklyNotes: false; default: true }
    }
}

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    public var dailyNoteID: UUID?
    public var dailyOpened = false
    public var weeklyNoteID: UUID?
    public var weekKey: String
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    public init(at: Date = .now, timeZone: TimeZone = .current) {
        let current = WeekCalendar.range(containing: at, timeZone: timeZone)
        weekKey = WeekCalendar.range(containing: current.start.addingTimeInterval(-1), timeZone: timeZone).startDay
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        guard scope.isReading else { return }
        readers[scope] = state
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
