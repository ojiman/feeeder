import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct DailyNotesTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    let jst = TimeZone(identifier: "Asia/Tokyo")!
    @Test func repeatDoesNotOverwriteMemo() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let first = try store.scrap(articleID: article.id, at: at, timeZone: jst)
        try store.saveScrapMemo(key: first.key, memo: "本人のメモ", at: at)
        article.summary = "更新後の要約"
        let repeated = try store.scrap(articleID: article.id, at: at.addingTimeInterval(30), timeZone: jst)
        #expect(first.key == repeated.key && store.scraps.count == 1)
        #expect(repeated.summary == "合成RSS要約" && repeated.memo == "本人のメモ" && repeated.savedAt == at)
        let later = at.addingTimeInterval(31 * 86_400)
        try store.purgeExpired(at: later)
        for feed in store.feeds { try store.unsubscribe(feed) }
        let reopened = try ReaderStore(url: library.url, now: later)
        #expect(reopened.scraps.first?.summary == "合成RSS要約")
        #expect(reopened.scraps.first?.memo == "本人のメモ")
    }
    @Test func missingOrExpiredSummaryStoresLinksOnly() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = ""
        #expect(try store.content(articleID: article.id, at: at)?.text.isEmpty == false)
        let empty = try store.scrap(articleID: article.id, at: at, timeZone: jst)
        #expect(empty.summary.isEmpty && empty.coverageRaw == ContentCoverage.unavailable.rawValue)
        let other = store.articles[1]
        let expired = try store.scrap(articleID: other.id, at: at.addingTimeInterval(31 * 86_400), timeZone: jst)
        #expect(expired.summary.isEmpty && expired.title == other.title && expired.url == other.originalURL)
    }
    @Test func frozenDayAndOverlappingIntervals() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = jst
        let midnight = calendar.startOfDay(for: at).addingTimeInterval(86_400)
        let article = store.articles[0]
        let first = try store.scrap(articleID: article.id, at: midnight.addingTimeInterval(-60), timeZone: jst)
        let timezoneChanged = try store.scrap(articleID: article.id, at: midnight.addingTimeInterval(-30), timeZone: TimeZone(secondsFromGMT: -8 * 3600)!)
        #expect(first.noteID == timezoneChanged.noteID)
        let tomorrow = try store.scrap(articleID: article.id, at: midnight, timeZone: jst)
        #expect(tomorrow.noteID != first.noteID)
        let overlap = DailyNote(start: midnight.addingTimeInterval(-3600), end: midnight.addingTimeInterval(3600), timeZoneID: "UTC", day: "overlap", at: midnight.addingTimeInterval(1))
        store.context.insert(overlap); try store.save(); try store.reload()
        #expect(store.dailyNote(containing: midnight)?.id == overlap.id)
        try store.removeScrap(key: first.key)
        #expect(store.dailyNotes.count == 3)
        try store.deleteDailyNote(id: tomorrow.noteID)
        #expect(!store.scraps.contains { $0.noteID == tomorrow.noteID })
    }
    @Test func failureLeavesNoPartialNote() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: library.url, cloudKitDatabase: .none)])
        var fail = true
        let store = try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if fail { fail = false; throw CocoaError(.fileWriteUnknown) }
        })
        let id = store.articles[0].id
        #expect(throws: (any Error).self) { try store.scrap(articleID: id, at: at, timeZone: jst) }
        #expect(store.dailyNotes.isEmpty && store.scraps.isEmpty)
        _ = try store.scrap(articleID: id, at: at, timeZone: jst)
        #expect(store.dailyNotes.count == 1 && store.scraps.count == 1)
    }
}
