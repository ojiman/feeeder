import Foundation
import Testing
@testable import ReaderCore

@MainActor struct SingleLineTextTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)

    @Test func aNameLosesItsLineBreaksAndKeepsOneSpaceInstead() {
        #expect(SingleLineText.name("Feed\nName") == "Feed Name")
        #expect(SingleLineText.name("  A \r\n\n B\u{2028}C\u{2029}D  ") == "A B C D")
        #expect(SingleLineText.name("\n\n") == "")
        #expect(SingleLineText.name("日本語の 名前") == "日本語の 名前")                 // a space inside a line is kept
    }

    @Test func liveFilteringKeepsTrailingSpacesSoTypingIsNotBlocked() {
        #expect(SingleLineText.lineBreaksRemoved("a\nb ") == "a b ")
        #expect(SingleLineText.lineBreaksRemoved("x\r\ny") == "x y")
        #expect(SingleLineText.lineBreaksRemoved("no breaks") == "no breaks")
        #expect(SingleLineText.addressLive("https://x.example/\nfeed ") == "https://x.example/feed")   // an address has no white space at all
    }

    @Test func storedNamesAreSingleLine() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let feed = try #require(store.feeds.first)
        try store.updateSubscription(feed, title: "My\nFeed", folder: "Work\nReading")
        #expect(feed.title == "My Feed" && feed.folder == "Work Reading")
        try store.moveFeed(id: feed.id, toFolder: "A\nB")
        #expect(feed.folder == "A B")
        try store.renameFolder(from: "A B", to: "C\nD")
        #expect(feed.folder == "C D")
    }
}
