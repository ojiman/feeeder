import Testing
@testable import ReaderCore

struct NoteLayoutTests {
    @Test func theSidebarIsShownAtFirstFoldsOnTheNoteFaceAndComesBack() {
        var layout = NoteLayout()
        #expect(layout.columns == .all)
        layout.noteOpened()
        #expect(layout.columns == .doubleColumn && layout.sidebarFolded)
        layout.noteClosed()
        #expect(layout.columns == .all)
    }
    @Test func aChoiceMadeOnTheNoteFaceHoldsUntilTheFaceIsLeft() {
        var layout = NoteLayout()
        layout.noteOpened()
        layout.toggleSidebar()
        #expect(layout.columns == .all)                      // brought back by hand
        layout.toggleSidebar()
        #expect(layout.columns == .doubleColumn)
        layout.toggleSidebar()
        layout.noteClosed()
        #expect(layout.columns == .all)
        layout.noteOpened()
        #expect(layout.columns == .doubleColumn)             // folds again on the next entry
    }
    @Test func repeatedEntriesAndExitsAreHarmless() {
        var layout = NoteLayout()
        layout.noteClosed(); layout.noteClosed()
        #expect(layout.columns == .all)
        layout.noteOpened(); layout.noteOpened()
        #expect(layout.columns == .doubleColumn)
    }
    @Test func theLayoutFollowsAChangeMadeByTheWindow() {
        var layout = NoteLayout()
        layout.noteOpened()
        layout.follow(.all)
        #expect(!layout.sidebarFolded)
        layout.toggleSidebar()
        #expect(layout.columns == .doubleColumn)
    }
}
