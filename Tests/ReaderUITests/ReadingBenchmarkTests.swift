import Foundation
import ReaderCore
import Testing
@testable import UnagiReader

@MainActor struct ReadingBenchmarkTests {
    @Test func automationRefusesAnUnmarkedLibraryAndAnImplicitDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: (any Error).self) { try ReadingBenchmark.validateFixture(at: directory, explicit: true) }
        try Data("BenchmarkFixtureTests\n".utf8).write(to: directory.appending(path: ".reading-benchmark"))
        #expect(throws: (any Error).self) { try ReadingBenchmark.validateFixture(at: directory, explicit: false) }
        try ReadingBenchmark.validateFixture(at: directory, explicit: true)
    }

    @Test func syntheticRefreshParsesOneHundredEntriesWithoutNetwork() async throws {
        let client = FeedClient(http: ReadingBenchmark.SyntheticHTTP())
        let url = URL(string: "https://synthetic.example/feeds/3")!
        guard case .modified(let feed, _, _) = try await client.fetch(url: url) else {
            Issue.record("Expected a synthetic modified feed"); return
        }
        #expect(feed.sourceURL == url && feed.entries.count == 100)
        #expect(feed.entries.first?.sourceID == "3" && feed.entries.last?.sourceID == "9903")
        #expect(feed.entries.allSatisfy { $0.body.contains("合成段落 80") })
        await #expect(throws: (any Error).self) {
            _ = try await client.fetch(url: URL(string: "https://other.example/feeds/3")!)
        }
    }
}
