import Foundation
import Testing
@testable import ReaderCore

/// A store written by the build before decision 0019 (notes with goals, questions and answers) must open with the current schema.
/// Opt-in: make the fixture with `scripts/prepare-v1-store-fixture.sh <dir> 52429b44c647a4a3ee2c95fb039bf99d5e674f18` and set
/// `UNAGI_READER_PRE0019_FIXTURE_DIR` (also valid for a fixture made from the S1a merge commit `ae8aa781856a586ab6fa10d17449e16fa0cddda8`).

@MainActor struct PreNoteStoreUpgradeTests {
    struct Expected: Decodable {
        let baseline: String
        let at, firstReadAt: Double
        let feedID, articleID, themeID: UUID   // the key of the old fixtures' manifest
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["UNAGI_READER_PRE0019_FIXTURE_DIR"] != nil,
                   "Opt-in: set UNAGI_READER_PRE0019_FIXTURE_DIR to a fixture made from 52429b4 or from the S1a merge commit."))
    func aStoreWithGoalsQuestionsAndNotesStillOpens() throws {
        let path = try #require(ProcessInfo.processInfo.environment["UNAGI_READER_PRE0019_FIXTURE_DIR"])
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: source.appending(path: "expected.json")))
        #expect(["52429b44c647a4a3ee2c95fb039bf99d5e674f18", "ae8aa781856a586ab6fa10d17449e16fa0cddda8"].contains(expected.baseline))   // before decision 0019, and after S1a
        let library = try TestLibrary(); defer { library.cleanup() }
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            where file.lastPathComponent.hasPrefix("Reader.store") {
            try FileManager.default.copyItem(at: file, to: library.url.deletingLastPathComponent().appending(path: file.lastPathComponent))
        }
        let at = Date(timeIntervalSince1970: expected.at)
        for round in 0..<2 {                                                       // open, write, close, open again
            try autoreleasepool {
                let store = try ReaderStore(url: library.url, now: at)
                let article = try #require(store.articles.first)
                #expect(store.feeds.map(\.id) == [expected.feedID])
                #expect(store.feeds.first?.title == "合成購読" && store.feeds.first?.folder == "技術")
                #expect(article.id == expected.articleID && article.title == "合成記事" && article.starredAt == at)
                #expect(article.firstReadAt == Date(timeIntervalSince1970: expected.firstReadAt) && article.isRead)
                // Decision 0019 (S1b): the theme entity became the note entity, so the old themes, their notes and their article
                // records are not carried over. Everything outside them is.
                if round == 0 {
                    #expect(store.notes.isEmpty && store.noteArticles.isEmpty)
                    let note = try store.createNote(text: "# 開いたあとのノート\n", at: at)
                    try store.addArticle(expected.articleID, toNote: note.id, at: at)
                    #expect(store.notes.map(\.id) == [note.id])
                } else {
                    #expect(store.notes.map(\.title) == ["開いたあとのノート"] && store.noteArticles.count == 1)
                }
            }
        }
    }
}
