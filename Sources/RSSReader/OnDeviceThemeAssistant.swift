import Foundation
import NaturalLanguage
import ReaderCore

struct EmbeddedVector: Sendable, Equatable {
    let space: String
    let values: [Float]
}

protocol TextEmbedder: Sendable {
    func availability() async -> AssistantAvailability
    func vector(for text: String) async -> EmbeddedVector?
}

/// `NLContextualEmbedding`: Japanese text uses the Japanese model, other Latin-script languages the Latin-script
/// model, and anything else gets no vector. Only assets already on the device are used; the app never asks the
/// system to download any (decision 0009). An article's vector is the mean of its token vectors.
actor ContextualTextEmbedder: TextEmbedder {
    enum Space: String { case japanese = "ja", latin = "latin" }
    private var models: [Space: NLContextualEmbedding] = [:]
    private var loaded: Set<Space> = []
    private var cache: [String: EmbeddedVector] = [:]
    private let cacheLimit = 600

    private func model(for space: Space) -> NLContextualEmbedding? {
        if let model = models[space] { return model }
        let model = switch space {
        case .japanese: NLContextualEmbedding(language: .japanese)
        case .latin: NLContextualEmbedding(script: .latin)
        }
        models[space] = model
        return model
    }

    func availability() async -> AssistantAvailability {
        let available = [Space.japanese, .latin].compactMap { model(for: $0) }
        if available.isEmpty { return .unsupported }
        return available.contains { $0.hasAvailableAssets } ? .available : .assetsMissing
    }

    func vector(for text: String) async -> EmbeddedVector? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let hit = cache[text] { return hit }
        guard let (space, language) = Self.route(text), let model = readyModel(for: space),
              let result = try? model.embeddingResult(for: text, language: language) else { return nil }
        var sum = [Double](repeating: 0, count: model.dimension), count = 0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            for index in 0..<min(vector.count, sum.count) { sum[index] += vector[index] }
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        let vector = EmbeddedVector(space: space.rawValue, values: sum.map { Float($0 / Double(count)) })
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[text] = vector
        return vector
    }

    /// The model only when its assets are already on the device; `load()` runs once.
    private func readyModel(for space: Space) -> NLContextualEmbedding? {
        guard let model = model(for: space), model.hasAvailableAssets else { return nil }
        if !loaded.contains(space) {
            guard (try? model.load()) != nil else { return nil }
            loaded.insert(space)
        }
        return model
    }

    private static let latinLanguages: Set<NLLanguage> = Set(NLContextualEmbedding(script: .latin)?.languages ?? [])

    /// Kana means Japanese. Kanji-only headlines are often labelled Chinese by the recognizer, so Japanese is
    /// given a head start; other Latin-script languages go to the Latin model, anything else gets no vector.
    static func route(_ text: String) -> (Space, NLLanguage)? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) }) { return (.japanese, .japanese) }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageHints = [.japanese: 0.6, .english: 0.3, .simplifiedChinese: 0.05, .traditionalChinese: 0.05]
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        if language == .japanese || language == .simplifiedChinese || language == .traditionalChinese { return (.japanese, .japanese) }
        if latinLanguages.contains(language) { return (.latin, language) }
        return nil
    }
}

actor OnDeviceThemeAssistant: ThemeAssistant {
    private let embedder: any TextEmbedder
    init(embedder: any TextEmbedder = ContextualTextEmbedder()) { self.embedder = embedder }

    func availability() async -> AssistantAvailability { await embedder.availability() }

    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch] {
        let pool = try await embed([item] + candidates.flatMap(\.members) + background)
        return ThemeRanking.nearest(articleID: item.id, pool: pool, candidates: candidates.map { ($0.themeID, $0.members.map(\.id)) })
    }

    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]] {
        let embedded = try await embed(items + background)
        let wanted = Set(items.map(\.id))
        let centered = EmbeddingMath.centered(embedded).filter { wanted.contains($0.id) }
        return ThemeClustering.clusters(of: centered, threshold: SuggestionTuning.clusterThreshold)
    }

    private func embed(_ items: [SuggestionItem]) async throws -> [EmbeddedItem] {
        var seen = Set<UUID>(), result: [EmbeddedItem] = []
        for item in items where seen.insert(item.id).inserted {
            try Task.checkCancellation()
            if let vector = await embedder.vector(for: item.text) {
                result.append(EmbeddedItem(id: item.id, space: vector.space, vector: vector.values))
            }
        }
        return result
    }
}
