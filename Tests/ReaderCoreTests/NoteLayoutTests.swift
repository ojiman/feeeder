import Testing
@testable import ReaderCore

struct NoteLayoutTests {
    @Test func theSidebarIsShownAtFirstFoldsOnTheNoteFaceAndComesBack() {
        var layout = NoteLayout()
        #expect(layout.columns == .all)
        layout.enterNoteFace()
        #expect(layout.columns == .doubleColumn && layout.sidebarFolded)
        layout.leaveNoteFace()
        #expect(layout.columns == .all)
    }
    @Test func aChoiceMadeOnTheNoteFaceHoldsUntilTheFaceIsLeft() {
        var layout = NoteLayout()
        layout.enterNoteFace()
        layout.toggleSidebar()
        #expect(layout.columns == .all)                      // brought back by hand
        layout.toggleSidebar()
        #expect(layout.columns == .doubleColumn)
        layout.toggleSidebar()
        layout.leaveNoteFace()
        #expect(layout.columns == .all)
        layout.enterNoteFace()
        #expect(layout.columns == .doubleColumn)             // folds again on the next entry
    }
    @Test func repeatedEntriesAndExitsAreHarmless() {
        var layout = NoteLayout()
        layout.leaveNoteFace(); layout.leaveNoteFace()
        #expect(layout.columns == .all)
        layout.enterNoteFace(); layout.enterNoteFace()
        #expect(layout.columns == .doubleColumn)
    }
    @Test func theLayoutFollowsAChangeMadeByTheWindow() {
        var layout = NoteLayout()
        layout.enterNoteFace()
        layout.follow(.all)
        #expect(!layout.sidebarFolded)
        layout.toggleSidebar()
        #expect(layout.columns == .doubleColumn)
    }
}
