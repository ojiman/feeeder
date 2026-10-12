import Foundation
import Testing
@testable import ReaderCore

struct ReaderWorkspaceTests {
    @Test func goingToAnotherScopeAndBackRestoresTheReader() {
        var workspace = ReaderWorkspaceState()
        let article = UUID(), top = UUID()
        var reader = ReaderSelectionState(); reader.select(article); reader.listScrollAnchor = top
        reader.recordScroll(articleID: article, anchor: "paragraph-9", offset: 521)
        workspace.rememberReader(reader, in: .unread)
        workspace.noteOpen = true
        workspace.scope = .starred
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(workspace.noteOpen)                                                      // what the person chose is kept across scopes
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }

    /// Decision 0049: the one note starts closed, and stays as the person left it while the app runs.
    @Test func theNoteStartsClosedAndStaysAsTheyLeftIt() {
        var workspace = ReaderWorkspaceState()
        #expect(!workspace.noteOpen)
        workspace.noteOpen = true
        workspace.scope = .starred; workspace.scope = .all
        #expect(workspace.noteOpen)
        workspace.noteOpen = false
        workspace.scope = .unread
        #expect(!workspace.noteOpen)
    }

    @Test func openingAndClosingTheNoteLeavesTheReaderAlone() {
        var workspace = ReaderWorkspaceState()
        let article = UUID()
        var reader = ReaderSelectionState(); reader.select(article)
        reader.recordScroll(articleID: article, anchor: "p-3", offset: 120)
        workspace.rememberReader(reader, in: .starred)
        workspace.noteOpen = true
        workspace.noteOpen = false
        let restored = workspace.reader(in: .starred)
        #expect(restored.selectedArticleID == article && restored.scrollOffsets[article] == 120 && restored.scrollAnchors[article] == "p-3")
    }
}
