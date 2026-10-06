import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct AIHandoffFixtureTests {
    @Test func storedLongJapaneseAndSummarySourcesProduceCompletePackage() throws {
        let temporary = try TestLibrary(); defer { temporary.cleanup() }
        let directory = ProcessInfo.processInfo.environment["FEEEDER_AI_PROBE_DIRECTORY"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? temporary.directory
        let (store, package) = try fixture(directory: directory, lineCount: 500)
        #expect(package.text.contains("0500: ") && package.text.contains("END_A_20261005"))
        #expect(package.text.contains("END_B_20261005") && package.text.contains("RSS summary only; full body unavailable"))
        #expect(store.articles.allSatisfy { $0.firstReadAt == nil && !$0.isRead })
    }

    @Test func storedLargeSourceExportsLosslessUTF8Parts() throws {
        let temporary = try TestLibrary(); defer { temporary.cleanup() }
        let directory = ProcessInfo.processInfo.environment["FEEEDER_AI_LARGE_PROBE_DIRECTORY"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? temporary.directory
        let (_, package) = try fixture(directory: directory, lineCount: 10_000)
        #expect(package.text.utf8.count > 1_048_576)
        let parts = AIPackageBuilder.split(package)
        #expect(parts.count > 1)
        var restored = Data()
        for part in parts {
            #expect(part.count <= 1_048_576)
            let text = try #require(String(data: part, encoding: .utf8))
            let separator = try #require(text.range(of: "\n\n"))
            restored.append(contentsOf: text[separator.upperBound...].utf8)
        }
        #expect(restored == Data(package.text.utf8))
        #expect(package.text.contains("10000: ") && package.text.contains("END_A_20261005"))
    }

    private func fixture(directory: URL, lineCount: Int) throws -> (ReaderStore, AIPackage) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Reader", schema: schema, url: directory.appending(path: "Reader.store"), cloudKitDatabase: .none)])
        let context = ModelContext(container); context.autosaveEnabled = false
        #expect(try context.fetchCount(FetchDescriptor<Article>()) == 0)
        let now = Date.now
        let feed = Feed(title: "合成AI連携テスト", symbol: "doc.text"); context.insert(feed)
        let text = "START_A_20261005\n" + (1...lineCount).map { String(format: "%04d: 合成記事の本文です。これは実際の記事ではありません。長い本文と日本語の保持を確認します。", $0) }.joined(separator: "\n") + "\nEND_A_20261005"
        let a = Article(feedID: feed.id, title: "Source A 合成\(lineCount)行", summary: "合成全文の要約", publisher: "source-a.example", publishedAt: now, receivedAt: now)
        a.originalURL = "https://source-a.example/article/1"
        context.insert(a); context.insert(ContentSnapshot(articleID: a.id, text: text, coverage: .extracted))
        let b = Article(feedID: feed.id, title: "Source B RSS要約のみ", summary: "START_B_20261005\n合成RSS要約。全文は取得できていません。含まれていない本文を推測しないでください。\nEND_B_20261005", publisher: "source-b.example", publishedAt: now.addingTimeInterval(-1), receivedAt: now)
        b.originalURL = "https://source-b.example/article/2"; context.insert(b)
        for article in [a, b] { context.insert(FeedMembership(feedID: feed.id, articleID: article.id, sourceID: article.title)) }
        try context.save()
        let store = try ReaderStore(container: container, now: now)
        let package = try AIPackageBuilder.build(sources: store.aiSources(articleIDs: [a.id, b.id], at: now), language: "日本語", createdAt: now, expiresAt: now.addingTimeInterval(86_400))
        #expect(package.text.contains(text) && package.text.contains(b.summary))
        return (store, package)
    }
}
