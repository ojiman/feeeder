import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor
struct ReaderStoreTests {
    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rss-reader-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Reader.store")
    }

    @Test func seedingTwiceDoesNotDuplicateArticlesOrFeeds() throws {
        let url = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try ReaderStore(url: url, seedDemo: true)
        let ids = store.articles.map(\.id)
        try store.seedIfEmpty()
        #expect(store.articles.map(\.id) == ids)
        #expect(store.articles.count == 6)
        #expect(store.feeds.count == 3)
    }

    @Test func keyboardSelectionClampsToVisibleList() {
        let ids = [UUID(), UUID(), UUID()]
        #expect(ReaderNavigation.move(nil, by: 1, in: ids) == ids[0])
        #expect(ReaderNavigation.move(ids[0], by: -1, in: ids) == ids[0])
        #expect(ReaderNavigation.move(ids[2], by: 1, in: ids) == ids[2])
        #expect(ReaderNavigation.move(ids[0], by: 1, in: ids) == ids[1])
        #expect(ReaderNavigation.move(nil, by: 1, in: []) == nil)
    }
}
