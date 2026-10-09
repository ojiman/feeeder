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
        workspace.switchFace(of: themeID, to: .questions, rememberingReader: ReaderSelectionState())
        workspace.scope = .unfiledStars
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(workspace.face(of: themeID) == .questions)
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }
    @Test func themeFacesGateReadingAndKeepTheSavedReader() {
        var workspace = ReaderWorkspaceState()
        let themeID = UUID(), other = UUID()
        #expect(workspace.face(of: themeID) == .articles && workspace.isReading(.theme(themeID)))
        #expect(workspace.isReading(.unfiledStars) && workspace.isReading(.all))
        let article = UUID()
        var reader = ReaderSelectionState(); reader.select(article)
        workspace.switchFace(of: themeID, to: .questions, rememberingReader: reader)
        #expect(workspace.face(of: themeID) == .questions && !workspace.isReading(.theme(themeID)))
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == article)
        #expect(workspace.face(of: other) == .articles)
        var later = ReaderSelectionState(); later.select(UUID())
        workspace.switchFace(of: themeID, to: .articles, rememberingReader: later)
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == article)
        #expect(workspace.isReading(.theme(themeID)))
        workspace.switchFace(of: themeID, to: .questions, rememberingReader: later)
        var third = ReaderSelectionState(); third.select(UUID())
        workspace.rememberReader(third, in: .theme(themeID))
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == later.selectedArticleID)
    }

    @Test func questionSelectionIsPerThemeAndDefaultsToUnderstanding() {
        var workspace = ReaderWorkspaceState()
        let first = UUID(), second = UUID(), question = UUID()
        #expect(workspace.questionSelection(of: first) == .understanding)
        workspace.selectQuestion(.question(question), in: first)
        #expect(workspace.questionSelection(of: first) == .question(question))
        #expect(workspace.questionSelection(of: second) == .understanding)
        workspace.selectQuestion(.understanding, in: first)
        #expect(workspace.questionSelection(of: first) == .understanding)
    }
}
