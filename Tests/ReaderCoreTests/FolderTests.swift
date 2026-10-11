import Foundation
import Testing
@testable import ReaderCore

@MainActor struct FolderTests {
    @Test func sharedArticleCountsOnce() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url)
        for name in ["a", "b"] {
            let feed = try store.importFeed(FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://synthetic.example/" + name)!))
            try store.moveFeed(id: feed.id, toFolder: " 技術 ")
        }
        let article = try #require(store.articles.first)
        #expect(store.folderArticleIDs(folder: "技術", keeping: nil) == [article.id])
        #expect(store.folderUnreadCount(folder: "技術") == 1)
        try store.markDisplayed(articleID: article.id, at: .now)
        #expect(store.folderUnreadCount(folder: "技術") == 0)
    }
    @Test func movingAndRenamingRetainsSelection() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now, store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0], feed = try #require(store.feed(id: article.feedID))
        let note = try store.createNote(text: "# A\n", at: at)
        let link = try store.addArticle(article.id, toNote: note.id, at: at)
        try store.moveFeed(id: feed.id, toFolder: " 技術 ")
        let selected = store.folderArticleIDs(folder: "技術", keeping: article.id)
        try store.renameFolder(from: "技術", to: "技術")
        #expect(store.folderArticleIDs(folder: "技術", keeping: article.id) == selected)
        let other = try #require(store.feeds.first { $0.id != feed.id })
        try store.moveFeed(id: other.id, toFolder: "趣味")
        try store.renameFolder(from: "技術", to: " 趣味 ")
        #expect(feed.folder == "趣味" && store.feeds.filter { $0.folder == "技術" }.isEmpty)
        try store.moveFeed(id: feed.id, toFolder: "")
        #expect(store.folderArticleIDs(folder: "趣味", keeping: article.id).contains(article.id))
        #expect(!store.folderArticleIDs(folder: "趣味", keeping: nil).contains(article.id))
        try store.unsubscribe(feed)
        #expect(store.noteArticles.first?.summary == link.summary)
        let reopened = try ReaderStore(url: library.url)
        #expect(reopened.feed(id: other.id)?.folder == "趣味")
    }
}
