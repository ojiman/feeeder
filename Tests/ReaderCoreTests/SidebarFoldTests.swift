import Testing
@testable import ReaderCore

/// Decision 0046: the sidebar folds when the original page opens, however wide the window is, and comes back when the page closes.
struct SidebarFoldTests {
    @Test func theSidebarFoldsWhileTheOriginalPageIsOpen() {
        #expect(SidebarFold.folded(pageOpen: true, noteLayout: .all))
        #expect(SidebarFold.folded(pageOpen: true, noteLayout: .doubleColumn))
        #expect(!SidebarFold.folded(pageOpen: false, noteLayout: .all))
    }

    @Test func aFoldTheNoteLayoutAsksForSurvivesTheClosingOfThePage() {
        #expect(SidebarFold.folded(pageOpen: false, noteLayout: .doubleColumn))     // a note panel in a narrow window keeps it folded
    }

    @Test func oneMoveOfAboutAThirdOfASecond() {
        #expect(SidebarFold.motionDuration == 0.3)
    }
}
