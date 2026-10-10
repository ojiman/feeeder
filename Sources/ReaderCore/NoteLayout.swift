import Foundation

/// Which columns the window shows. `doubleColumn` is the middle and right column with the sidebar folded away.
public enum SidebarColumns: Sendable, Equatable { case all, doubleColumn }

/// When the sidebar folds. It folds when the person opens a note's note and comes back when they close it. While the note stays
/// open their own choice holds, also across a switch to another note whose note is open too.
public struct NoteLayout: Equatable, Sendable {
    public private(set) var sidebarFolded = false
    public init() {}
    public mutating func noteOpened() { sidebarFolded = true }
    public mutating func noteClosed() { sidebarFolded = false }
    public mutating func toggleSidebar() { sidebarFolded.toggle() }
    /// The window changed the columns by itself (for example a drag); follow it so the next toggle goes the right way.
    public mutating func follow(_ columns: SidebarColumns) { sidebarFolded = columns == .doubleColumn }
    public var columns: SidebarColumns { sidebarFolded ? .doubleColumn : .all }
}
