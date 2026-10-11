import Testing
@testable import ReaderCore

struct NoteLayoutTests {
    private let wide: Double = 1_600, narrow: Double = 1_000

    @Test func theSidebarFoldsWhenAPanelOpensOnlyBelowTheThreshold() {
        #expect(NoteLayout.foldBelow == 1_300)
        var layout = NoteLayout()
        #expect(layout.columns == .all)
        layout.noteOpened(windowWidth: 1_299)
        #expect(layout.columns == .doubleColumn && layout.sidebarFolded)
        layout.noteClosed()
        #expect(layout.columns == .all)
        layout.noteOpened(windowWidth: 1_300)                                   // exactly the threshold is wide enough
        #expect(layout.columns == .all && !layout.sidebarFolded)
        layout.noteClosed()
        layout.noteOpened(windowWidth: wide)
        #expect(layout.columns == .all)
    }

    @Test func aChoiceMadeByHandHoldsUntilThePanelIsClosed() {
        var layout = NoteLayout()
        layout.noteOpened(windowWidth: narrow)
        layout.toggleSidebar()
        #expect(layout.columns == .all)                                         // brought back by hand
        layout.windowWidthChanged(to: 900)                                      // a resize does not undo the person's choice
        #expect(layout.columns == .all)
        layout.toggleSidebar()
        #expect(layout.columns == .doubleColumn)
        layout.noteClosed()
        #expect(layout.columns == .all)
        layout.noteOpened(windowWidth: narrow)
        #expect(layout.columns == .doubleColumn)                                // folds again on the next opening
    }

    @Test func resizingWhileThePanelIsOpenFoldsAndUnfoldsUnlessTheChoiceWasMade() {
        var layout = NoteLayout()
        layout.noteOpened(windowWidth: wide)
        #expect(layout.columns == .all)
        layout.windowWidthChanged(to: narrow)
        #expect(layout.columns == .doubleColumn)
        layout.windowWidthChanged(to: wide)
        #expect(layout.columns == .all)
    }

    @Test func aResizeWithNoPanelOpenChangesNothing() {
        var layout = NoteLayout()
        layout.windowWidthChanged(to: narrow)
        #expect(layout.columns == .all)
        layout.noteOpened(windowWidth: wide); layout.noteClosed()
        layout.windowWidthChanged(to: narrow)
        #expect(layout.columns == .all)
    }

    @Test func repeatedOpeningsAndClosingsAreHarmless() {
        var layout = NoteLayout()
        layout.noteClosed(); layout.noteClosed()
        #expect(layout.columns == .all)
        layout.noteOpened(windowWidth: narrow); layout.noteOpened(windowWidth: narrow)
        #expect(layout.columns == .doubleColumn)
    }

    @Test func theLayoutFollowsAChangeMadeByTheWindow() {
        var layout = NoteLayout()
        layout.noteOpened(windowWidth: narrow)
        layout.follow(.all)
        #expect(!layout.sidebarFolded)
        layout.toggleSidebar()
        #expect(layout.columns == .doubleColumn)
    }
}
