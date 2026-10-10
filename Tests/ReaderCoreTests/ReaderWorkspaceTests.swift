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
        workspace.switchFace(of: themeID, to: .note, rememberingReader: ReaderSelectionState())
        workspace.scope = .unfiledStars
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(workspace.face(of: themeID) == .note)
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }
    @Test func bothFacesOfAThemeShareOneReader() {
        var workspace = ReaderWorkspaceState()
        let themeID = UUID(), other = UUID()
        #expect(workspace.face(of: themeID) == .articles)
        let first = UUID(), second = UUID()
        var reader = ReaderSelectionState(); reader.select(first)
        workspace.switchFace(of: themeID, to: .note, rememberingReader: reader)
        #expect(workspace.face(of: themeID) == .note && workspace.face(of: other) == .articles)
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == first)
        // The article chosen on the note face is the one the articles face shows after going back.
        var chosen = ReaderSelectionState(); chosen.select(second)
        chosen.recordScroll(articleID: second, anchor: "p-3", offset: 120)
        workspace.rememberReader(chosen, in: .theme(themeID))
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == second)
        workspace.switchFace(of: themeID, to: .articles, rememberingReader: chosen)
        let restored = workspace.reader(in: .theme(themeID))
        #expect(restored.selectedArticleID == second && restored.scrollOffsets[second] == 120 && restored.scrollAnchors[second] == "p-3")
        // And back again: leaving the articles face saves it as before.
        var later = ReaderSelectionState(); later.select(first)
        workspace.switchFace(of: themeID, to: .note, rememberingReader: later)
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == first)
    }
}
