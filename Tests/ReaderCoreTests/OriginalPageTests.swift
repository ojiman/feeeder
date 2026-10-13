import Foundation
import Testing
@testable import ReaderCore

// Checks PRD-01 (specification 7).
struct OriginalPageTests {
    @Test func selectingAnotherArticleReturnsToReaderWithoutOpeningItsOriginal() {
        let a = UUID(), b = UUID(), c = UUID()
        var state = OriginalPageState()
        _ = state.open(articleID: a, url: "https://synthetic.example/a")
        let changed = state.selectionChanged(to: b)
        #expect(changed)
        #expect(state.articleID == nil && state.url == nil)
        _ = state.open(articleID: b, url: "https://synthetic.example/b")
        let unchanged = state.selectionChanged(to: b)
        #expect(!unchanged)
        #expect(state.articleID == b && state.url?.path == "/b")
        let changedAgain = state.selectionChanged(to: c)
        #expect(changedAgain)
        #expect(state.articleID == nil && state.url == nil)
        _ = state.open(articleID: a, url: "https://synthetic.example/a")
        let cleared = state.selectionChanged(to: nil)
        #expect(cleared)
        #expect(state.articleID == nil && state.url == nil)
    }
    @Test func theOriginalPageClosesOnlyWhenAnotherArticleIsSelected() {
        let a = UUID(), b = UUID()
        var state = OriginalPageState()
        #expect(!state.closesWhenSelecting(b))                                   // nothing is open
        _ = state.open(articleID: a, url: "https://synthetic.example/a")
        #expect(!state.closesWhenSelecting(a))                                   // the same article
        #expect(state.closesWhenSelecting(b) && state.closesWhenSelecting(nil))
        #expect(state.url != nil)                                                // asking does not close it: the slide-out comes first
    }
    @Test func originalPageRouteValidatesURLAndClearsOnClose() {
        let id = UUID()
        var state = OriginalPageState()
        let rejected = state.open(articleID: id, url: "file:///private/tmp/page.html")
        #expect(!rejected)
        #expect(state.url == nil)
        let opened = state.open(articleID: id, url: "https://publisher.example/1")
        #expect(opened)
        #expect(state.articleID == id)
        #expect(state.url?.host == "publisher.example")
        state.close()
        #expect(state.url == nil)
        #expect(state.articleID == nil)
    }
}
