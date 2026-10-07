import Foundation
import Testing
@testable import ReaderCore

@MainActor struct V1StoreUpgradeTests {
    struct Expected: Decodable {
        let baseline: String
        let at, start, end, firstReadAt: Double
        let feedID, articleID, noteID, periodID: UUID
        let dailyNoteID: UUID?
        let scrapKey: String?
    }
    @Test func preservesReleasedV1Store() throws {
        let path = try #require(ProcessInfo.processInfo.environment["FEEEDER_V1_FIXTURE_DIR"], "Run scripts/prepare-v1-store-fixture.sh and set FEEEDER_V1_FIXTURE_DIR")
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: source.appending(path: "expected.json")))
        #expect(["53102cc42ea665b3379ad2a23d842c3186ad9c3e", "f9db83b49a82947a7031ddf874bc94fcb91ef89d"].contains(expected.baseline))
        let library = try TestLibrary(); defer { library.cleanup() }
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            where file.lastPathComponent.hasPrefix("Reader.store") {
            try FileManager.default.copyItem(at: file, to: library.url.deletingLastPathComponent().appending(path: file.lastPathComponent))
        }
        let at = Date(timeIntervalSince1970: expected.at)
        for _ in 0..<2 {
            try autoreleasepool {
                let store = try ReaderStore(url: library.url, now: at)
                let article = try #require(store.articles.first)
                #expect(store.feeds.map(\.id) == [expected.feedID])
                #expect(store.feeds.first?.title == "合成購読" && store.feeds.first?.folder == "技術")
                #expect(article.id == expected.articleID && article.title == "合成記事")
                #expect(article.firstReceivedAt == at && article.firstReadAt == Date(timeIntervalSince1970: expected.firstReadAt))
                #expect(article.identityKey == "https://synthetic.example/article/1" && article.isRead)
                #expect(store.retentionDays == 90 && store.memberships.count == 1)
                #expect(try store.content(articleID: article.id, at: at)?.text == "合成RSS要約")
                #expect(store.weeks.first?.id == expected.periodID && store.weeks.first?.timeZoneID == "Asia/Tokyo")
                #expect(store.weeks.first?.start == Date(timeIntervalSince1970: expected.start))
                #expect(store.weeks.first?.end == Date(timeIntervalSince1970: expected.end))
                #expect(store.notes.first?.id == expected.noteID && store.notes.first?.text == "残す合成ノート")
                #expect(store.noteSources.first?.title == "合成記事" && store.noteSources.first?.url == "https://synthetic.example/article/1")
                #expect(article.starredAt == (expected.scrapKey == nil ? nil : at) && article.imageURL == nil)
                #expect(store.noteSources.first?.summary == nil)
                if let dailyID = expected.dailyNoteID, let scrapKey = expected.scrapKey {
                    #expect(store.dailyNotes.map(\.id) == [dailyID])
                    #expect(store.scraps.map(\.key) == [scrapKey] && store.scraps.first?.summary == "合成RSS要約")
                } else { #expect(store.dailyNotes.isEmpty && store.scraps.isEmpty) }
                #expect(try store.content(articleID: article.id, at: at)?.bodyParagraphs.first?.links.isEmpty == true)
            }
        }
    }
}
