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
        let store = try ReaderStore(url: url)
        let ids = store.articles.map(\.id)
        try store.seedIfEmpty()
        #expect(store.articles.map(\.id) == ids)
        #expect(store.articles.count == 6)
        #expect(store.feeds.count == 3)
    }

    @Test func readAndLikeSurviveReopeningPersistentStore() throws {
        let url = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let id: UUID = try autoreleasepool {
            let store = try ReaderStore(url: url)
            let article = try #require(store.articles.first)
            try store.setRead(article, true)
            try store.toggleLike(article, at: Date(timeIntervalSince1970: 1_000))
            return article.id
        }
        let reopened = try ReaderStore(url: url)
        let article = try #require(reopened.articles.first { $0.id == id })
        #expect(article.isRead)
        #expect(reopened.like(for: article)?.likedAt == Date(timeIntervalSince1970: 1_000))
        #expect(reopened.body(for: article)?.contains("合成記事") == true)
    }

    @Test func unlikeThenRelikeUsesNewTimestampWithoutDuplicatingLike() throws {
        let url = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try ReaderStore(url: url)
        let article = try #require(store.articles.first)
        try store.toggleLike(article, at: Date(timeIntervalSince1970: 100))
        try store.toggleLike(article, at: Date(timeIntervalSince1970: 200))
        #expect(store.like(for: article) == nil)
        try store.toggleLike(article, at: Date(timeIntervalSince1970: 300))
        #expect(store.likes.count == 1)
        #expect(store.like(for: article)?.likedAt == Date(timeIntervalSince1970: 300))
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
