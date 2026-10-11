import Foundation
import Testing
@testable import ReaderCore

struct ReaderWorkspaceTests {
    @Test func noteRoundTripRestoresReader() {
        var workspace = ReaderWorkspaceState()
        let article = UUID(), top = UUID(), noteID = UUID()
        var reader = ReaderSelectionState(); reader.select(article); reader.listScrollAnchor = top
        reader.recordScroll(articleID: article, anchor: "paragraph-9", offset: 521)
        workspace.rememberReader(reader, in: .unread)
        workspace.scope = .note(noteID)
        workspace.setNote(open: false, of: noteID)
        workspace.scope = .starred
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(!workspace.isNoteOpen(of: noteID))                                       // what the person chose is kept across scopes
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }
    /// Decision 0019: selecting a note opens its panel at once; only a note the person closed stays closed (while the app runs).
    @Test func aNotesPanelIsOpenAtFirstAndAClosedOneStaysClosedForThatNote() {
        var workspace = ReaderWorkspaceState()
        let first = UUID(), second = UUID()
        #expect(workspace.isNoteOpen(of: first) && workspace.isNoteOpen(of: second))
        workspace.setNote(open: false, of: first)
        #expect(!workspace.isNoteOpen(of: first) && workspace.isNoteOpen(of: second))
        workspace.scope = .note(second); workspace.scope = .all; workspace.scope = .note(first)
        #expect(!workspace.isNoteOpen(of: first))                                       // remembered while the app runs
        workspace.setNote(open: false, of: first)                                       // closing twice is harmless
        workspace.setNote(open: true, of: first)
        #expect(workspace.isNoteOpen(of: first))
        workspace.setNote(open: true, of: second)                                       // opening what is open is harmless
        #expect(workspace.isNoteOpen(of: second))
    }

    @Test func openingAndClosingTheNoteLeavesTheNotesReaderAlone() {
        var workspace = ReaderWorkspaceState()
        let noteID = UUID(), article = UUID()
        var reader = ReaderSelectionState(); reader.select(article)
        reader.recordScroll(articleID: article, anchor: "p-3", offset: 120)
        workspace.rememberReader(reader, in: .note(noteID))
        workspace.setNote(open: true, of: noteID)
        workspace.setNote(open: false, of: noteID)
        let restored = workspace.reader(in: .note(noteID))
        #expect(restored.selectedArticleID == article && restored.scrollOffsets[article] == 120 && restored.scrollAnchors[article] == "p-3")
    }
}
