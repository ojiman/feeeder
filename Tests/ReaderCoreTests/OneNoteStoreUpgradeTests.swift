import Foundation
import Testing
@testable import ReaderCore

/// A store written by the build before decision 0049 (several notes, and records of the articles in each) must open with the current
/// schema, keep the note that was edited last, and lose the others and the records.
/// Opt-in: make the fixture with `scripts/prepare-v1-store-fixture.sh /private/tmp/unagi-reader-<name> 60da7dff8ff3741afc0707652bedea256f9e83df`
/// and set `UNAGI_READER_PRE0049_FIXTURE_DIR` to it.
@MainActor struct OneNoteStoreUpgradeTests {
    struct Expected: Decodable {
        let baseline: String
        let at, firstReadAt, keptUpdatedAt: Double
        let feedID, keptNoteID: UUID
        let articleIDs, deletedNoteIDs: [UUID]
        let keptText: String
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["UNAGI_READER_PRE0049_FIXTURE_DIR"] != nil,
                   "Opt-in: set UNAGI_READER_PRE0049_FIXTURE_DIR to a fixture made from 60da7df."))
    func aStoreWithSeveralNotesAndTheirArticleRecordsOpensWithOneNote() throws {
        let path = try #require(ProcessInfo.processInfo.environment["UNAGI_READER_PRE0049_FIXTURE_DIR"])
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: source.appending(path: "expected.json")))
        #expect(expected.baseline == "60da7dff8ff3741afc0707652bedea256f9e83df")
        let library = try TestLibrary(); defer { library.cleanup() }
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            where file.lastPathComponent.hasPrefix("Reader.store") {
            try FileManager.default.copyItem(at: file, to: library.url.deletingLastPathComponent().appending(path: file.lastPathComponent))
        }
        let at = Date(timeIntervalSince1970: expected.at)
        for round in 0..<3 {                                                       // open, write, close, open again, open again
            try autoreleasepool {
                let store = try ReaderStore(url: library.url, now: at.addingTimeInterval(Double(round + 1) * 1_000))
                // Everything outside the notes is as it was.
                #expect(store.feeds.map(\.id) == [expected.feedID] && store.feeds.first?.title == "合成購読" && store.feeds.first?.folder == "技術")
                #expect(Set(store.articles.map(\.id)) == Set(expected.articleIDs))
                let first = store.article(id: expected.articleIDs[0])
                #expect(first?.starredAt == at && first?.firstReadAt == Date(timeIntervalSince1970: expected.firstReadAt))
                // Exactly one note: the one edited last, with its text and its dates; the others are gone.
                #expect(store.notes.count == 1)
                #expect(store.note?.id == expected.keptNoteID)
                for id in expected.deletedNoteIDs { #expect(!store.notes.contains { $0.id == id }) }
                if round == 0 {
                    #expect(store.note?.text == expected.keptText && store.note?.updatedAt == Date(timeIntervalSince1970: expected.keptUpdatedAt))
                    try store.saveNote(text: expected.keptText + "\n続き", at: at.addingTimeInterval(5_000))
                } else {
                    #expect(store.note?.id == expected.keptNoteID && store.note?.text == expected.keptText + "\n続き")
                }
            }
        }
    }
}
