import Foundation
import Testing
@testable import ReaderCore

@MainActor struct WeeklyNotesTests {
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let la = TimeZone(identifier: "America/Los_Angeles")!

    @Test func mondayWeekCrossesYearAndDST() {
        let year = WeekCalendar.range(containing: date("2026-01-01T03:00:00Z"), timeZone: tokyo)
        #expect(year.startDay == "2025-12-29" && year.endDay == "2026-01-04")
        #expect(year.start == date("2025-12-28T15:00:00Z"))
        let spring = WeekCalendar.range(containing: date("2026-03-08T20:00:00Z"), timeZone: la)
        let fall = WeekCalendar.range(containing: date("2026-11-01T20:00:00Z"), timeZone: la)
        #expect(spring.end.timeIntervalSince(spring.start) == 167 * 3600)
        #expect(fall.end.timeIntervalSince(fall.start) == 169 * 3600)
    }

    @Test func onlyActualFirstReadInHalfOpenWeekIsCandidate() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true)
        let range = WeekCalendar.range(containing: date("2026-10-05T03:00:00Z"), timeZone: tokyo)
        let ids = store.articles.map(\.id)
        try store.markDisplayed(articleID: ids[0], at: range.start)
        try store.markDisplayed(articleID: ids[1], at: range.end)
        try store.setRead(store.articles[2], true)
        #expect(store.candidates(in: range).map(\.id) == [ids[0]])
    }

    @Test func frozenWeekSurvivesTimezoneChangeAndDST() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true)
        let now = date("2026-03-04T12:00:00Z")
        let range = WeekCalendar.range(containing: now, timeZone: tokyo)
        let article = try #require(store.articles.first)
        try store.markDisplayed(articleID: article.id, at: now)
        let first = try store.createNote(in: range, title: "週", at: now)
        let changed = WeekCalendar.range(containing: now, timeZone: la)
        let second = try store.createNote(in: changed, title: "追加", at: now)
        #expect(first.weekID == second.weekID)
        let period = try #require(store.weeks.first)
        #expect(period.range == range)
        #expect(period.timeZoneID == "Asia/Tokyo")
        #expect(store.candidates(in: period.range).map(\.id) == [article.id])
    }

    @Test func multipleNotesShareFrozenRange() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = date("2026-10-05T03:00:00Z")
        let range = WeekCalendar.range(containing: now, timeZone: tokyo)
        let noteID = try autoreleasepool {
            let store = try ReaderStore(url: library.url)
            _ = try store.importFeed(FeedParser.parse(Data(FeedParserTests.rss.utf8), sourceURL: URL(string: "https://feed.example/rss")!), receivedAt: now)
            let article = try #require(store.articles.first)
            let feed = try #require(store.feeds.first)
            let notes = try ["週", "技術", "学び"].map { try store.createNote(in: range, title: $0, at: now) }
            #expect(notes.filter(\.isDefault).count == 1)
            #expect(Set(notes.map(\.weekID)).count == 1)
            try store.saveNote(id: notes[0].id, text: "自分の記録", at: now)
            try store.adoptSources(noteID: notes[0].id, articleIDs: [article.id, article.id])
            #expect(store.noteSources.count == 1)
            try store.unsubscribe(feed)
            return notes[0].id
        }
        let reopened = try ReaderStore(url: library.url)
        let note = try #require(reopened.notes.first { $0.id == noteID })
        #expect(note.text == "自分の記録")
        #expect(reopened.notes.count == 3 && reopened.weeks.count == 1 && reopened.feeds.isEmpty)
        let source = try #require(reopened.noteSources.first)
        #expect(source.url == "https://publisher.example/posts/1")
        #expect(!source.title.isEmpty)
        try reopened.deleteNote(id: noteID)
        #expect(reopened.notes.count == 2 && reopened.noteSources.isEmpty)
    }

    @Test func notesAndReadingDataSurviveReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = date("2026-10-05T03:00:00Z")
        try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true)
            let id = try #require(store.articles.first).id
            try store.markDisplayed(articleID: id, at: now)
            _ = try store.createNote(in: WeekCalendar.range(containing: now, timeZone: tokyo), title: "記録", at: now)
        }
        let store = try ReaderStore(url: library.url)
        #expect(store.articles.count == 6 && store.feeds.count == 3 && store.notes.count == 1)
        #expect(store.articles.filter { $0.firstReadAt == now }.count == 1)
    }
}
