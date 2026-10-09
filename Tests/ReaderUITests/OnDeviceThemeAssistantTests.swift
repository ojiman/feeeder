import Foundation
import Testing
import ReaderCore
@testable import RSSReader

/// Keyword-driven stand-in for the real embedding.
private final class KeywordEmbedder: TextEmbedder, @unchecked Sendable {
    private let lock = NSLock()
    private var counted = 0
    var onFirstCall: (@Sendable () -> Void)?
    var calls: Int { lock.withLock { counted } }
    func availability() async -> AssistantAvailability { .available }
    func vector(for text: String) async -> EmbeddedVector? {
        let first = lock.withLock { counted += 1; return counted == 1 }
        if first { onFirstCall?() }
        if text.contains("UNEMBEDDABLE") { return nil }
        if text.contains("finance") { return EmbeddedVector(space: "latin", values: [9, 1, 0]) }
        if text.contains("金利") { return EmbeddedVector(space: "ja", values: [10, 1, 0]) }
        if text.contains("住宅") { return EmbeddedVector(space: "ja", values: [10, 0, 1]) }
        if text.contains("料理") { return EmbeddedVector(space: "ja", values: [0, 10, 1]) }
        if text.contains("レシピ") { return EmbeddedVector(space: "ja", values: [1, 10, 0]) }
        return EmbeddedVector(space: "ja", values: [-4, -4, 4])
    }
}

struct OnDeviceThemeAssistantTests {
    func item(_ text: String) -> SuggestionItem { SuggestionItem(id: UUID(), text: text) }
    let background = (0..<4).map { SuggestionItem(id: UUID(), text: "背景 \($0)") }

    @Test func clustersGroupByTopicAndSkipWhatCannotBeEmbedded() async throws {
        let embedder = KeywordEmbedder()
        let assistant = OnDeviceThemeAssistant(embedder: embedder)
        let items = [item("金利が上がる"), item("住宅ローン"), item("料理の基本"), item("レシピ帳"), item("UNEMBEDDABLE"), item("finance news")]
        let groups = try await assistant.clusters(of: items, background: background)
        let ids = items.map(\.id)
        #expect(groups.contains([ids[0], ids[1]]) && groups.contains([ids[2], ids[3]]))
        #expect(!groups.joined().contains(ids[4]))                              // not embeddable: no suggestion, no crash
        #expect(!groups.contains { $0.contains(ids[5]) && $0.count > 1 })        // another space is never merged into the Japanese groups
        #expect(!groups.joined().contains { $0 == background[0].id })            // background shapes the average only
    }

    @Test func nearestThemesPutsTheThemeWithSimilarMembersFirst() async throws {
        let assistant = OnDeviceThemeAssistant(embedder: KeywordEmbedder())
        let subject = item("金利の話")
        let money = ThemeCandidateInput(themeID: UUID(), members: [item("住宅ローン"), item("金利と家計")])
        let food = ThemeCandidateInput(themeID: UUID(), members: [item("料理の基本"), item("レシピ帳")])
        let matches = try await assistant.nearestThemes(for: subject, candidates: [food, money], background: background)
        #expect(matches.map(\.themeID) == [money.themeID])
    }

    @Test func aDifferentSpaceNeverMatches() async throws {
        let assistant = OnDeviceThemeAssistant(embedder: KeywordEmbedder())
        let subject = item("finance news")
        let candidate = ThemeCandidateInput(themeID: UUID(), members: [item("金利と家計"), item("住宅ローン")])
        let matches = try await assistant.nearestThemes(for: subject, candidates: [candidate], background: background)
        #expect(matches.isEmpty)
    }

    @Test func cancellationStopsTheEmbeddingLoop() async throws {
        let embedder = KeywordEmbedder()
        let assistant = OnDeviceThemeAssistant(embedder: embedder)
        let items = (0..<20).map { item("金利 \($0)") }
        final class Holder: @unchecked Sendable { var task: Task<[[UUID]], any Error>? }
        let holder = Holder()
        embedder.onFirstCall = { holder.task?.cancel() }
        holder.task = Task { try await assistant.clusters(of: items, background: []) }
        await #expect(throws: CancellationError.self) { try await holder.task!.value }
        #expect(embedder.calls < items.count)
    }

    @Test func japaneseHeadlinesAreRoutedToTheJapaneseModelEvenWithoutKana() {
        for text in ["日銀が政策金利を引き上げ、住宅ローン金利も上昇する見通し", "金利上昇と家計負担", "日銀政策金利引上", "住宅ローン", "AIモデルの量子化"] {
            #expect(ContextualTextEmbedder.route(text)?.0 == .japanese, "\(text)")
        }
        #expect(ContextualTextEmbedder.route("The central bank raised interest rates again this week")?.0 == .latin)
        #expect(ContextualTextEmbedder.route("")?.0 == nil)
        #expect(ContextualTextEmbedder.route("한국어 기사 제목입니다")?.0 == nil)
    }

    @Test func availabilityPassesThrough() async {
        let state = await OnDeviceThemeAssistant(embedder: KeywordEmbedder()).availability()
        #expect(state == .available)
    }

    /// Decision 0009: the app never starts a system-asset download by itself. Guard the sources against the call.
    @Test func sourcesNeverRequestSystemAssets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let enumerator = try #require(FileManager.default.enumerator(at: root.appending(path: "Sources"), includingPropertiesForKeys: nil))
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            #expect(!(try String(contentsOf: url, encoding: .utf8)).contains("requestAssets"), "\(url.lastPathComponent) requests assets")
        }
        #expect(scanned > 10)
    }

    /// Opt-in: runs the real on-device embedding on synthetic Japanese sentences and prints what it finds, for the
    /// verification record. Quality is judged by a person, not asserted. FEEEDER_RUN_ONDEVICE_AI=1 to run.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FEEEDER_RUN_ONDEVICE_AI"] == "1"))
    func realEmbeddingSmoke() async throws {
        let assistant = OnDeviceThemeAssistant()
        let state = await assistant.availability()
        #expect(state == .available)
        let topics = [
            ["日銀が政策金利を引き上げ、住宅ローン金利も上昇する見通し", "変動金利型の住宅ローンを組む家計の返済負担が増える", "預金金利の上昇で家計の貯蓄行動はどう変わるか", "インフレと賃金上昇の関係を家計の視点で読む"],
            ["小型のAIモデルを端末内で動かすための量子化の基本", "オンデバイスAIのレイテンシとプライバシーの両立", "ローカルで動く大規模言語モデルの推論最適化", "AIモデルの蒸留で軽量化する手法のまとめ"],
            ["睡眠の質を上げるための就寝前の習慣", "朝の光を浴びると体内時計が整う", "昼寝の長さと夜の眠りの関係", "カフェインを摂る時間帯が睡眠に与える影響"]
        ]
        let items = topics.flatMap { $0 }.map { item($0) }
        let bg = ["新しいカメラの発表会", "週末の天気と花粉の予報", "地方の鉄道路線の見直し", "映画賞のノミネート発表"].map { item($0) }
        let groups = try await assistant.clusters(of: items, background: bg)
        let titles = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.text) })
        for group in groups { print("CLUSTER", group.map { titles[$0] ?? "?" }) }
        #expect(!groups.isEmpty)
    }
}
