import Foundation
import Testing
@testable import ReaderCore

struct OriginalPageTests {
    @Test func movingOriginalTracksSelectedArticle() {
        let a = UUID(), b = UUID(), c = UUID()
        var state = OriginalPageState()
        _ = state.open(articleID: a, url: "https://synthetic.example/a")
        state.followSelection(articleID: b, url: "https://synthetic.example/b")
        #expect(state.articleID == b && state.url?.path == "/b")
        state.followSelection(articleID: c, url: nil)
        #expect(state.articleID == nil && state.url == nil)
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
