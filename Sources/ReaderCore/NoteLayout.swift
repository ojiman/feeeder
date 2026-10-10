import Foundation

/// Which columns the window shows. `doubleColumn` is the middle and right column with the sidebar folded away.
public enum SidebarColumns: Sendable, Equatable { case all, doubleColumn }

/// When the sidebar folds. A note's panel needs room: the sidebar, the list, the article and the panel add up to at least
/// 1,125 pt (185 + 280 + 360 + 300), so the sidebar folds when a panel opens in a window narrower than `foldBelow`, and comes back
/// when the panel closes. While the panel stays open, a resize folds or unfolds it the same way, unless the person has chosen by
/// hand; that choice holds until the panel is closed (also across a switch to another note whose panel is open).
public struct NoteLayout: Equatable, Sendable {
    /// A proposal (decision 0019, S1b): to be checked in a real window.
    public static let foldBelow: Double = 1_200
    public private(set) var sidebarFolded = false
    private var panelOpen = false
    private var chosenByHand = false
    public init() {}
    public mutating func noteOpened(windowWidth: Double) {
        panelOpen = true; chosenByHand = false
        sidebarFolded = windowWidth < Self.foldBelow
    }
    public mutating func noteClosed() { panelOpen = false; chosenByHand = false; sidebarFolded = false }
    public mutating func toggleSidebar() { sidebarFolded.toggle(); chosenByHand = true }
    /// The window was resized.
    public mutating func windowWidthChanged(to width: Double) {
        guard panelOpen, !chosenByHand else { return }
        sidebarFolded = width < Self.foldBelow
    }
    /// The window changed the columns by itself (for example a drag); follow it so the next toggle goes the right way.
    public mutating func follow(_ columns: SidebarColumns) { sidebarFolded = columns == .doubleColumn }
    public var columns: SidebarColumns { sidebarFolded ? .doubleColumn : .all }
}
