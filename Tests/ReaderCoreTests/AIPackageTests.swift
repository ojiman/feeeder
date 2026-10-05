import Foundation
import CryptoKit
import Testing
@testable import ReaderCore

@MainActor struct AIPackageTests {
    func source(_ title: String, text: String, coverage: ContentCoverage) -> AISource {
        let id = UUID(), url = URL(string: "https://synthetic.example/" + title)!
        return AISource(articleID: id, title: title, url: url,
            content: ArticleContent(articleID: id, text: text, summary: "合成要約", coverage: coverage, originalURL: url))
    }
    @Test func wholeSourcesLanguageCoverageAndHashArePreserved() throws {
        let text = (1...500).map { String(format: "%04d: 合成本文", $0) }.joined(separator: "\n") + "\nEND_A"
        let a = source("A", text: text, coverage: .extracted)
        let b = source("B", text: "合成RSS要約\nEND_B", coverage: .summaryOnly)
        let now = Date.now
        let package = try AIPackageBuilder.build(sources: [a, b], language: "日本語", createdAt: now, expiresAt: now.addingTimeInterval(86_400))
        #expect(package.text.contains(text) && package.text.contains(b.content.text))
        #expect(package.text.contains("Output language: 日本語") && package.text.contains("https://synthetic.example/B"))
        #expect(package.text.contains("RSS summary only; full body unavailable"))
        #expect(package.text.contains("含まれていない本文を推測しない"))
        #expect(package.text.hasSuffix("END_PACKAGE\n"))
        #expect(package.sha256 == SHA256.hash(data: Data(package.text.utf8)).map { String(format: "%02x", $0) }.joined())
        let excluded = try AIPackageBuilder.build(sources: [a], language: "English", createdAt: now, expiresAt: package.expiresAt)
        #expect(excluded.sources.map(\.articleID) == [a.articleID])
        #expect(!excluded.text.contains(b.articleID.uuidString) && !excluded.text.contains("END_B"))
        #expect(throws: (any Error).self) { try AIPackageBuilder.build(sources: [], language: "日本語", createdAt: now, expiresAt: package.expiresAt) }
    }
    @Test func splitPreservesEveryUTF8ByteAndSourceMapping() throws {
        let a = source("huge", text: String(repeating: "日本語の本文🍵\n", count: 120_000) + "END_HUGE", coverage: .extracted)
        let now = Date.now
        let package = try AIPackageBuilder.build(sources: [a], language: "日本語", createdAt: now, expiresAt: now.addingTimeInterval(86_400))
        let parts = AIPackageBuilder.split(package)
        #expect(parts.count > 1 && parts.allSatisfy { $0.count <= 1_048_576 })
        var restored = Data()
        for (index, part) in parts.enumerated() {
            let text = try #require(String(data: part, encoding: .utf8))
            #expect(text.contains("Part: \(index + 1)/\(parts.count)") && text.contains(a.articleID.uuidString))
            let delimiter = try #require(part.range(of: Data("\n\n".utf8)))
            restored.append(part[delimiter.upperBound...])
        }
        #expect(restored == Data(package.text.utf8))
    }
    @Test func reviewInvalidatesWhenSourceExpiresOrChanges() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: now)
        let id = try #require(store.articles.first).id
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: [id], language: "日本語", at: now)
        #expect(throws: (any Error).self) { try review.validated(at: now.addingTimeInterval(86_400)) }
        #expect(review.package == nil)
        try review.build(articleIDs: [id], language: "日本語", at: now)
        try store.saveExtractedContent(articleID: id, result: ExtractionResult(text: "新しい合成本文", coverage: .extracted, sourceURL: URL(string: "https://synthetic.example/changed")!), at: now)
        #expect(throws: (any Error).self) { try review.validated(at: now) }
        #expect(review.package == nil && review.reason != nil)
    }
    @Test func reviewClearsWhenRetentionShortensOrContentIsDeleted() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now, old = now.addingTimeInterval(-10 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: old)
        let ids = store.articles.map(\.id)
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: ids, language: "日本語", at: now)
        try store.applyRetention(days: 7, at: now)
        #expect(review.package == nil && review.reason != nil)
        #expect(throws: (any Error).self) { try review.validated(at: now) }
        #expect(try store.aiSources(articleIDs: ids, at: now).isEmpty)
        let second = try TestLibrary(); defer { second.cleanup() }
        let fresh = try ReaderStore(url: second.url, seedDemo: true, now: now)
        let id = try #require(fresh.articles.first).id
        let freshReview = AIPackageReview(store: fresh, now: { now })
        try freshReview.build(articleIDs: [id], language: "日本語", at: now)
        try fresh.deleteContent(articleIDs: [id], at: now)
        #expect(freshReview.package == nil)
    }
    @Test func lifetimeShortensWithoutExtendingOrReviving() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let now = Date.now, received = now.addingTimeInterval(-6.5 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: received)
        let id = try #require(store.articles.first).id
        let review = AIPackageReview(store: store, now: { now })
        try review.build(articleIDs: [id], language: "日本語", at: now)
        let original = try #require(review.package)
        try store.applyRetention(days: 7, at: now)
        #expect(review.package?.expiresAt == received.addingTimeInterval(7 * 86_400))
        #expect(review.package?.sha256 == original.sha256)
        try store.applyRetention(days: 365, at: now)
        #expect(review.package?.expiresAt == received.addingTimeInterval(7 * 86_400))
    }
}
