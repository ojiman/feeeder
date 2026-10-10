import Foundation
import Testing
@testable import ReaderCore

/// A store written by the build before decision 0019 (themes with goals, questions and answers) must open with the current schema.
/// Opt-in: make the fixture with `scripts/prepare-v1-store-fixture.sh <dir> 52429b44c647a4a3ee2c95fb039bf99d5e674f18` and set
/// `FEEEDER_PRE0019_FIXTURE_DIR`. The goal, the questions and the answers are dropped by the schema change; nothing else is lost.
@MainActor struct PreNoteStoreUpgradeTests {
    struct Expected: Decodable {
        let baseline: String
        let at, firstReadAt: Double
        let feedID, articleID, themeID: UUID
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FEEEDER_PRE0019_FIXTURE_DIR"] != nil,
                   "Opt-in: set FEEEDER_PRE0019_FIXTURE_DIR to a fixture made from 52429b4."))
    func aStoreWithGoalsQuestionsAndNotesStillOpens() throws {
        let path = try #require(ProcessInfo.processInfo.environment["FEEEDER_PRE0019_FIXTURE_DIR"])
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: source.appending(path: "expected.json")))
        #expect(expected.baseline == "52429b44c647a4a3ee2c95fb039bf99d5e674f18")
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
                #expect(store.themes.map(\.id) == [expected.themeID])
                #expect(store.themes.first?.name == "合成テーマ")
                #expect(store.themeArticles.count == 1)
                if round == 0 {
                    #expect(store.themes.first?.note == "残す合成ノート")
                    try store.saveNote(themeID: expected.themeID, text: "開いたあとの合成ノート", at: at)
                }
                else { #expect(store.themes.first?.note == "開いたあとの合成ノート") }
            }
        }
    }
}
