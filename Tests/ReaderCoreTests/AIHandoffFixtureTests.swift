import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct AIHandoffFixtureTests {
    @Test func storedLongJapaneseNoteProducesCompletePackage() throws {
        let temporary = try TestLibrary(); defer { temporary.cleanup() }
        let directory = ProcessInfo.processInfo.environment["UNAGI_READER_AI_PROBE_DIRECTORY"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? temporary.directory
        let (store, package) = try fixture(directory: directory, lineCount: 500)
        #expect(package.text.contains("0500: ") && package.text.contains("END_A_20261005"))
        #expect(store.articles.allSatisfy { $0.firstReadAt == nil && !$0.isRead })
    }

    @Test func storedLargeNoteExportsLosslessUTF8Parts() throws {
        let temporary = try TestLibrary(); defer { temporary.cleanup() }
        let directory = ProcessInfo.processInfo.environment["UNAGI_READER_AI_LARGE_PROBE_DIRECTORY"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? temporary.directory
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
        let text = "START_A_20261005\n" + (1...lineCount).map { String(format: "%04d: 合成ノートの本文です。これは実際のノートではありません。長い本文と日本語の保持を確認します。", $0) }.joined(separator: "\n") + "\nEND_A_20261005"
        let note = Note(text: text, at: now)
        context.insert(note); try context.save()
        let store = try ReaderStore(container: container, now: now)
        let review = AIPackageReview(store: store, now: { now })
        try review.build(note: note.id, language: "日本語", at: now)
        let package = try #require(review.package)
        #expect(package.text.contains(text))
        return (store, package)
    }
}
