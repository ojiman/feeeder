import Foundation
import Testing
@testable import ReaderCore

struct ReaderSelectionTests {
    @Test func pageDirectionUsesListOrderForKeysAndClicks() {
        let ids = [UUID(), UUID(), UUID()]
        #expect(ReaderNavigation.isForward(from: ids[0], to: ids[2], in: ids))
        #expect(!ReaderNavigation.isForward(from: ids[2], to: ids[0], in: ids))
        #expect(ReaderNavigation.isForward(from: nil, to: ids[0], in: ids))
        #expect(ReaderNavigation.isForward(from: UUID(), to: ids[0], in: ids))
        #expect(ReaderNavigation.isForward(from: ids[0], to: nil, in: ids))
    }
    @Test func originalReturnKeepsSelectionParagraphOffsetAndListAnchor() {
        var state = ReaderSelectionState(); let id = UUID()
        state.select(id); state.recordScroll(articleID: id, anchor: "paragraph-7", offset: 23.5)
        state.listScrollAnchor = id
        state.returnFromOriginal()
        #expect(state.selectedArticleID == id && state.visibleArticleID == id)
        #expect(state.scrollAnchors[id] == "paragraph-7" && state.scrollOffsets[id] == 23.5)
        #expect(state.listScrollAnchor == id && state.listFocusRequested)
        state.select(UUID()); state.select(id)
        #expect(state.scrollAnchors[id] == "paragraph-7")
    }
    @Test func rapidSelectionKeepsLatestArticle() {
        var state = ReaderSelectionState()
        let ids = (0..<20).map { _ in UUID() }
        for id in ids { state.select(id) }
        #expect(state.selectedArticleID == ids.last && state.visibleArticleID == ids.last)
        state.select(nil)
        #expect(state.selectedArticleID == nil && state.visibleArticleID == nil)
        #expect(ReaderNavigation.move(nil, by: 1, in: []) == nil)
        #expect(ReaderNavigation.move(ids.first, by: -1, in: ids) == ids.first)
        #expect(ReaderNavigation.move(ids.last, by: 1, in: ids) == ids.last)
    }
    @Test @MainActor func selectedUnreadRowRemainsUntilMovingToNext() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true)
        let first = try #require(store.articles.first)
        let next = store.articles[1].id
        try store.markDisplayed(articleID: first.id, at: .now)
        let visible = store.visibleArticles(feedID: nil, unreadOnly: true, keeping: first.id)
        #expect(visible.first?.id == first.id)
        #expect(ReaderNavigation.move(first.id, by: 1, in: visible.map(\.id)) == next)
        let feed = try #require(store.feeds.first)
        try store.unsubscribe(feed)
        #expect(store.visibleArticles(feedID: feed.id, unreadOnly: false, keeping: nil).isEmpty)
    }
    @Test func textEditingAndIMEDoNotPermitReaderShortcuts() {
        #expect(!ReaderShortcutPolicy.permits(textInput: true, markedText: false, sheet: false, originalPage: false))
        #expect(!ReaderShortcutPolicy.permits(textInput: false, markedText: true, sheet: false, originalPage: false))
        #expect(!ReaderShortcutPolicy.permits(textInput: false, markedText: false, sheet: true, originalPage: false))
        #expect(!ReaderShortcutPolicy.permits(textInput: false, markedText: false, sheet: false, originalPage: true))
        #expect(ReaderShortcutPolicy.permits(textInput: false, markedText: false, sheet: false, originalPage: false))
    }
}
