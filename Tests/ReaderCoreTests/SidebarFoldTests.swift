import Foundation
import Testing
@testable import ReaderCore

/// Decisions 0046 and 0049: the left panels fold while the original page or the note is open.
struct SidebarFoldTests {
    @Test func oneMoveOfAboutAThirdOfASecond() {
        #expect(SidebarFold.motionDuration == 0.3)
    }

    @Test func theSidebarFoldsWhileThePageOrTheNoteIsOpen() {
        #expect(!SidebarFold.folded(pageOpen: false, noteOpen: false))
        #expect(SidebarFold.folded(pageOpen: true, noteOpen: false))
        #expect(SidebarFold.folded(pageOpen: false, noteOpen: true))
    }

    @Test func closingThePageWhileTheNoteIsOpenDoesNotBringTheSidebarBack() {
        #expect(SidebarFold.folded(pageOpen: true, noteOpen: true))
        #expect(SidebarFold.folded(pageOpen: false, noteOpen: true))
    }

    @Test func theListFoldsWithTheNoteUnlessThePersonShowedIt() {
        #expect(SidebarFold.listFolded(noteOpen: true, listShown: false))
        #expect(!SidebarFold.listFolded(noteOpen: true, listShown: true))
    }

    @Test func withTheNoteClosedTheListIsAlwaysThere() {
        #expect(!SidebarFold.listFolded(noteOpen: false, listShown: false))
        #expect(!SidebarFold.listFolded(noteOpen: false, listShown: true))
    }
}
