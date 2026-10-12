import Foundation
import Testing
@testable import ReaderCore

/// Decision 0046: the sidebar folds when the original page opens and when a note is shown, however wide the window is, and comes back
/// when the page closes or the person leaves the note screen.
struct SidebarFoldTests {
    @Test func theSidebarFoldsWhileTheOriginalPageIsOpen() {
        #expect(SidebarFold.folded(pageOpen: true, noteScreen: false))
        #expect(!SidebarFold.folded(pageOpen: false, noteScreen: false))
    }

    @Test func theSidebarFoldsOnTheNoteScreenAndClosingThePageDoesNotBringItBack() {
        #expect(SidebarFold.folded(pageOpen: false, noteScreen: true))               // the note screen on its own
        #expect(SidebarFold.folded(pageOpen: true, noteScreen: true))                // a page opened over a note
    }

    @Test func oneMoveOfAboutAThirdOfASecond() {
        #expect(SidebarFold.motionDuration == 0.3)
    }

    @Test func leavingTheNoteScreenGoesBackToWhereThePersonWas() {
        var screens = NoteScreenReturn()
        screens.scopeChanged(from: .starred, to: .note(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        #expect(screens.target == .starred)                                          // ✕ goes back to Star
        screens.scopeChanged(from: .note(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!), to: .note(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!))
        #expect(screens.target == .starred)                                          // from one note to another: the place before the notes stays
        screens.scopeChanged(from: .note(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!), to: .unread)
        #expect(screens.target == .all)                                              // left the notes: nothing to go back to, the default is all articles
    }

    @Test func aNoteOpenedAtStartGoesBackToAllArticles() {
        var screens = NoteScreenReturn()
        screens.scopeChanged(from: nil, to: .note(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        #expect(screens.target == .all)
    }
}
