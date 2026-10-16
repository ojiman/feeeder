import Foundation

/// When the left panels fold away (decisions 0046 and 0049).
public enum SidebarFold {
    /// The fold, and the slide of the original page or of the note that goes with it, are one move of this many seconds.
    public static let motionDuration: Double = 0.3

    /// A window narrower than this folds and returns the list at once, without the system's move. In a narrow window the move ended the app
    /// in an exception (the window asked for more layout passes than it has views; #222), in about seven of nine tries; in a window of about
    /// 1,450 pt it did not. The sidebar, the note and the page keep their motion.
    public static let animatedListFoldMinimumWindowWidth: Double = 1_400

    public static func animatesListFold(windowWidth: Double) -> Bool {
        windowWidth >= animatedListFoldMinimumWindowWidth
    }

    /// The sidebar is folded while the original page is open and while the note is open, whatever the width of the window. Closing the
    /// page while the note is open must not bring it back.
    public static func folded(pageOpen: Bool, noteOpen: Bool) -> Bool {
        pageOpen || noteOpen
    }

    /// The list of articles is folded too while the note is open, unless the person showed it with the layout button: then the screen is
    /// the list, the article and the note. With the note closed the list is always there.
    public static func listFolded(noteOpen: Bool, listShown: Bool) -> Bool {
        noteOpen && !listShown
    }
}
