import Foundation

/// When the left panel (the sidebar) is folded away (decision 0046, after Reeder).
public enum SidebarFold {
    /// The fold, and the slide of the original page that goes with it, are one move of this many seconds.
    public static let motionDuration: Double = 0.3

    /// The sidebar is folded while the original page is open, whatever the width of the window. It is also folded while the note layout
    /// asks for it (a note panel in a narrow window); closing the page must not bring it back then.
    public static func folded(pageOpen: Bool, noteLayout: SidebarColumns) -> Bool {
        pageOpen || noteLayout != .all
    }
}
