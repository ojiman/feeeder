import Foundation
import Testing
import SwiftData
@testable import ReaderCore

@MainActor struct ContentRetentionTests {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let day: TimeInterval = 86_400
    func parsed() throws -> ParsedFeed {
        try FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://feed.example/rss")!)
    }
    @Test func thirtyDayBoundariesAndFirstReadAnchor() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, now: start)
        _ = try store.importFeed(parsed(), receivedAt: start)
        let article = try #require(store.articles.first)
        #expect(store.retentionDays == 30)
        #expect(try store.content(articleID: article.id, at: start.addingTimeInterval(30 * day - 1)) != nil)
        #expect(try store.content(articleID: article.id, at: start.addingTimeInterval(30 * day)) == nil)
        let read = start.addingTimeInterval(day)
        try store.markDisplayed(articleID: article.id, at: read)
        try store.setRead(article, false)
        #expect(try store.availableContentExpiries(at: read)[article.id] == start.addingTimeInterval(31 * day))
        #expect(try store.content(articleID: article.id, at: start.addingTimeInterval(31 * day)) == nil)
    }
    @Test func previewDoesNotMutateAndShorteningCommitsOnce() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, now: start)
        _ = try store.importFeed(parsed(), receivedAt: start)
        let id = try #require(store.articles.first).id
        var calls = 0
        store.onContentPolicyChanged = { calls += 1 }
        let later = start.addingTimeInterval(10 * day)
        let preview = try store.previewDeletion(days: 7, allContent: false, at: later)
        #expect(preview.articleIDs == [id] && preview.bodyCount == 1 && preview.summaryCount == 1 && preview.estimatedBytes > 0)
        #expect(store.retentionDays == 30 && calls == 0)
        #expect(try store.content(articleID: id, at: later) != nil)
        try store.applyRetention(days: 7, at: later)
        #expect(store.retentionDays == 7 && calls == 1)
        #expect(try store.availableContentExpiries(at: later)[id] == nil)
        #expect(try store.content(articleID: id, at: later) == nil)
        #expect(throws: (any Error).self) { try store.applyRetention(days: 0, at: later) }
        #expect(calls == 1 && store.retentionDays == 7)
    }
    @Test func expiredContentCannotBeReadOrReimported() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, now: start)
        _ = try store.importFeed(parsed(), receivedAt: start)
        let article = try #require(store.articles.first)
        let deadline = start.addingTimeInterval(30 * day)
        #expect(try store.content(articleID: article.id, at: deadline) == nil)
        _ = try store.importFeed(parsed(), receivedAt: deadline)
        #expect(article.summary.isEmpty && store.body(for: article, at: deadline) == nil)
        #expect(article.firstReceivedAt == start)
        try store.applyRetention(days: 365, at: deadline)
        _ = try store.importFeed(parsed(), receivedAt: deadline.addingTimeInterval(day))
        #expect(try store.content(articleID: article.id, at: deadline) == nil)
    }
    @Test func deletionProtectsNotesAndSourcesAcrossReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let noteID = try autoreleasepool {
            let store = try ReaderStore(url: library.url, now: start)
            let feed = try store.importFeed(parsed(), receivedAt: start)
            let article = try #require(store.articles.first)
            try store.markDisplayed(articleID: article.id, at: start)
            let range = WeekCalendar.range(containing: start, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
            let note = try store.createNote(in: range, title: "記録", at: start)
            try store.saveNote(id: note.id, text: "残すノート", at: start)
            try store.adoptSources(noteID: note.id, articleIDs: [article.id])
            try store.deleteContent(articleIDs: [article.id], at: start)
            try store.unsubscribe(feed)
            #expect(article.firstReadAt == start && article.firstReceivedAt == start)
            _ = try store.importFeed(parsed(), receivedAt: start.addingTimeInterval(day))
            #expect(try store.content(articleID: article.id, at: start) == nil)
            return note.id
        }
        let reopened = try ReaderStore(url: library.url, now: start.addingTimeInterval(90 * day))
        #expect(reopened.notes.first { $0.id == noteID }?.text == "残すノート")
        #expect(reopened.noteSources.first?.url == "https://publisher.example/posts/1")
        #expect(reopened.articles.count == 1 && reopened.articles.first?.summary == "")
    }
    @Test func purgeExpiresContentAndNotifiesOnlyForChange() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, now: start)
        _ = try store.importFeed(parsed(), receivedAt: start)
        var calls = 0; store.onContentPolicyChanged = { calls += 1 }
        let later = start.addingTimeInterval(30 * day)
        try store.purgeExpired(at: later)
        try store.purgeExpired(at: later)
        #expect(calls == 1 && store.articles.first?.summary == "")
        #expect(try store.availableContentExpiries(at: later).isEmpty)
    }
    @Test func failedSaveRollsBackAndDoesNotNotify() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let writable = try ReaderStore(url: library.url, now: start)
            _ = try writable.importFeed(parsed(), receivedAt: start)
            return try #require(writable.articles.first).id
        }
        let schema = Schema([Feed.self, Article.self, ContentSnapshot.self, FeedMembership.self,
                             WeeklyPeriod.self, WeeklyNote.self, NoteSource.self, ReaderSettings.self])
        let configuration = ModelConfiguration("Reader", schema: schema, url: library.url, allowsSave: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = try ReaderStore(container: container, now: start)
        var calls = 0; store.onContentPolicyChanged = { calls += 1 }
        let at = start.addingTimeInterval(10 * day)
        #expect(throws: (any Error).self) { try store.applyRetention(days: 7, at: at) }
        #expect(calls == 0 && store.retentionDays == 30)
        #expect(try store.content(articleID: id, at: at)?.text.contains("本文 & 補足") == true)
        #expect(try store.availableContentExpiries(at: at)[id] == start.addingTimeInterval(30 * day))
    }
}
