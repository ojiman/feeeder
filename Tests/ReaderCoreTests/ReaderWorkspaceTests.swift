import Foundation
import Testing
@testable import ReaderCore

struct ReaderWorkspaceTests {
    @Test func themeRoundTripRestoresReader() {
        var workspace = ReaderWorkspaceState()
        let article = UUID(), top = UUID(), themeID = UUID()
        var reader = ReaderSelectionState(); reader.select(article); reader.listScrollAnchor = top
        reader.recordScroll(articleID: article, anchor: "paragraph-9", offset: 521)
        workspace.rememberReader(reader, in: .unread)
        workspace.scope = .theme(themeID)
        workspace.setNote(open: true, of: themeID)
        workspace.scope = .unfiledStars
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(workspace.isNoteOpen(of: themeID))
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }
    @Test func aThemesNoteIsClosedAtFirstAndRememberedPerTheme() {
        var workspace = ReaderWorkspaceState()
        let first = UUID(), second = UUID()
        #expect(!workspace.isNoteOpen(of: first) && !workspace.isNoteOpen(of: second))
        workspace.setNote(open: true, of: first)
        #expect(workspace.isNoteOpen(of: first) && !workspace.isNoteOpen(of: second))
        workspace.scope = .theme(second); workspace.scope = .all; workspace.scope = .theme(first)
        #expect(workspace.isNoteOpen(of: first))                                        // remembered while the app runs
        workspace.setNote(open: true, of: first)                                        // opening twice is harmless
        workspace.setNote(open: false, of: first)
        #expect(!workspace.isNoteOpen(of: first))
        workspace.setNote(open: false, of: second)                                      // closing what is closed is harmless
        #expect(!workspace.isNoteOpen(of: second))
    }

    @Test func openingAndClosingTheNoteLeavesTheThemesReaderAlone() {
        var workspace = ReaderWorkspaceState()
        let themeID = UUID(), article = UUID()
        var reader = ReaderSelectionState(); reader.select(article)
        reader.recordScroll(articleID: article, anchor: "p-3", offset: 120)
        workspace.rememberReader(reader, in: .theme(themeID))
        workspace.setNote(open: true, of: themeID)
        workspace.setNote(open: false, of: themeID)
        let restored = workspace.reader(in: .theme(themeID))
        #expect(restored.selectedArticleID == article && restored.scrollOffsets[article] == 120 && restored.scrollAnchors[article] == "p-3")
    }
}
