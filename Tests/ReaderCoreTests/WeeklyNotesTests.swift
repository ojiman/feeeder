import Foundation
import Testing
@testable import ReaderCore

@MainActor struct WeeklyNotesTests {
    @Test func intentCandidatesUseSavedWeek() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = date("2026-10-05T03:00:00Z")
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0], readOnly = store.articles[1], boundary = store.articles[2]
        let week = WeekCalendar.range(containing: at, timeZone: tokyo)
        try store.markDisplayed(articleID: article.id, at: week.start.addingTimeInterval(-1))
        try store.markDisplayed(articleID: readOnly.id, at: at)
        try store.setStar(articleID: article.id, isStarred: true, at: week.start)
        try store.setStar(articleID: boundary.id, isStarred: true, at: week.end)
        #expect(store.weeklyCandidates(in: week).map(\.articleID) == [article.id])
        try store.setStar(articleID: article.id, isStarred: false, at: at)
        #expect(store.weeklyCandidates(in: week).isEmpty)
        let first = try store.scrap(articleID: article.id, at: at, timeZone: tokyo)
        let second = try store.scrap(articleID: article.id, at: at.addingTimeInterval(86_400), timeZone: tokyo)
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let candidate = try #require(store.weeklyCandidates(in: week).first)
        #expect(candidate.scraps.map(\.key) == [first.key, second.key])
        #expect(store.weeklyCandidates(in: week).count == 1)
        #expect(store.candidates(in: week).map(\.id) == [readOnly.id])
    }
    @Test func adoptedSummaryOutlivesDailyNote() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = date("2026-10-05T03:00:00Z")
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let scrap = try store.scrap(articleID: article.id, at: at, timeZone: tokyo)
        try store.saveScrapMemo(key: scrap.key, memo: "自分の考え", at: at)
        try store.saveDailyNote(id: scrap.noteID, text: "日次本文", at: at)
        let note = try store.createNote(in: WeekCalendar.range(containing: at, timeZone: tokyo), title: "週", at: at)
        try store.adoptScraps(noteID: note.id, scrapKeys: [scrap.key, scrap.key])
        let source = try #require(store.noteSources.first)
        #expect(source.summary == "合成RSS要約" && source.savedAt == at && source.title == scrap.title && source.url == scrap.url)
        #expect(note.text.isEmpty)
        let later = try store.scrap(articleID: article.id, at: at.addingTimeInterval(86_400), timeZone: tokyo)
        later.summary = "別の要約"; try store.adoptScraps(noteID: note.id, scrapKeys: [later.key])
        try store.deleteDailyNote(id: scrap.noteID)
        try store.purgeExpired(at: at.addingTimeInterval(31 * 86_400))
        #expect(source.summary == "合成RSS要約" && store.noteSources.count == 1)
    }
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let la = TimeZone(identifier: "America/Los_Angeles")!

    @Test func readHistoryWeeksRemainReachableBeforeCreatingNotes() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let historical = date("2026-09-16T03:00:00Z")
        let now = date("2026-10-05T03:00:00Z")
        let store = try ReaderStore(url: library.url, seedDemo: true, now: historical)
        let article = try #require(store.articles.first)
        try store.markDisplayed(articleID: article.id, at: historical)
        let options = store.availableWeeks(at: now, timeZone: tokyo)
        #expect(options.map(\.startDay) == ["2026-10-05", "2026-09-28", "2026-09-14"])
        let oldRange = try #require(options.first { $0.startDay == "2026-09-14" })
        #expect(store.candidates(in: oldRange).map(\.id) == [article.id])
        _ = try store.createNote(in: oldRange, title: "過去の振り返り", at: now)
        let changed = store.availableWeeks(at: now, timeZone: la)
        #expect(changed.first { $0.startDay == "2026-09-14" } == oldRange)
        #expect(store.weeks.count == 1)
    }

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
