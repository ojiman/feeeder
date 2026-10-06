import Foundation
import Testing
@testable import ReaderCore

struct ReaderWorkspaceTests {
    @Test func notesRoundTripRestoresReader() {
        let at = ISO8601DateFormatter().date(from: "2026-10-05T03:00:00Z")!
        var workspace = ReaderWorkspaceState(at: at, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let article = UUID(), top = UUID()
        var reader = ReaderSelectionState(); reader.select(article); reader.listScrollAnchor = top
        reader.recordScroll(articleID: article, anchor: "paragraph-9", offset: 521)
        workspace.rememberReader(reader, in: .unread)
        workspace.scope = .dailyNotes; workspace.dailyNoteID = UUID()
        workspace.scope = .weeklyNotes; workspace.weeklyNoteID = UUID()
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(workspace.weekKey == "2026-09-28")
        #expect(workspace.dailyNoteID != nil && workspace.weeklyNoteID != nil)
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }
}
