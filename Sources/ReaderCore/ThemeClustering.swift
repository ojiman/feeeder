import Foundation

/// A text turned into a vector. Vectors from different `space`s (embedding models) are never compared.
public struct EmbeddedItem: Sendable, Equatable {
    public let id: UUID
    public let space: String
    public let vector: [Float]
    public init(id: UUID, space: String, vector: [Float]) { self.id = id; self.space = space; self.vector = vector }
}

public struct ThemeMatch: Sendable, Equatable {
    public let themeID: UUID
    public let score: Float
    public init(themeID: UUID, score: Float) { self.themeID = themeID; self.score = score }
}

/// Tunable numbers for the on-device suggestions. Values come from the synthetic spike
/// (docs/verification/2026-10-10-on-device-ai-spike.md); their fit to real libraries is unverified.
public enum SuggestionTuning {
    public static let clusterThreshold: Float = 0.15
    public static let nearestThreshold: Float = 0.15
    public static let nearestTopSimilarities = 3
    public static let maximumSuggestedThemes = 3
    public static let minimumClusterSize = 2
    public static let minimumItemsToCluster = 3
    public static let maximumClusters = 5
    public static let maximumClusterItems = 120
    public static let maximumMembersPerTheme = 10
    public static let backgroundItems = 40
    public static let textCharacterLimit = 300
}

public enum EmbeddingMath {
    /// Cosine similarity; nil when the vectors differ in length, are empty, or one has no length.
    public static func cosine(_ a: [Float], _ b: [Float]) -> Float? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for index in a.indices { dot += a[index] * b[index]; na += a[index] * a[index]; nb += b[index] * b[index] }
        guard na > 0, nb > 0 else { return nil }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    /// Subtracts each space's mean from its items. Without this every vector points the same way and all
    /// items look alike (spike §1). Items keep their order; a space with a single item becomes the zero vector.
    public static func centered(_ items: [EmbeddedItem]) -> [EmbeddedItem] {
        var sums: [String: [Float]] = [:], counts: [String: Int] = [:]
        for item in items {
            var sum = sums[item.space] ?? [Float](repeating: 0, count: item.vector.count)
            guard sum.count == item.vector.count else { continue }
            for index in item.vector.indices { sum[index] += item.vector[index] }
            sums[item.space] = sum; counts[item.space, default: 0] += 1
        }
        return items.map { item in
            guard let sum = sums[item.space], sum.count == item.vector.count, let count = counts[item.space] else { return item }
            let mean = sum.map { $0 / Float(count) }
            return EmbeddedItem(id: item.id, space: item.space, vector: zip(item.vector, mean).map { $0 - $1 })
        }
    }
}

public enum ThemeClustering {
    /// Average-linkage agglomerative clustering of (already centered) vectors. Clusters never mix spaces.
    /// Deterministic: members keep input order; clusters are ordered by size (largest first), then by first member.
    public static func clusters(of items: [EmbeddedItem], threshold: Float) -> [[UUID]] {
        let count = items.count
        guard count > 0 else { return [] }
        var sums = [[Float]](repeating: [Float](repeating: -.infinity, count: count), count: count)
        for i in 0..<count {
            for j in (i + 1)..<max(count, i + 1) where j < count {
                let similarity = items[i].space == items[j].space ? EmbeddingMath.cosine(items[i].vector, items[j].vector) : nil
                sums[i][j] = similarity ?? -.infinity; sums[j][i] = sums[i][j]
            }
        }
        var members = (0..<count).map { [$0] }
        var alive = Array(0..<count)
        while alive.count > 1 {
            var best: (Float, Int, Int)?
            for a in 0..<alive.count {
                for b in (a + 1)..<alive.count {
                    let i = alive[a], j = alive[b]
                    let average = sums[i][j] / Float(members[i].count * members[j].count)
                    if average >= threshold, best == nil || average > best!.0 { best = (average, a, b) }
                }
            }
            guard let (_, a, b) = best else { break }
            let i = alive[a], j = alive[b]
            for other in alive where other != i && other != j { sums[i][other] += sums[j][other]; sums[other][i] = sums[i][other] }
            members[i] += members[j]; members[j] = []
            alive.remove(at: b)
        }
        let position = Dictionary(items.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        return alive.map { members[$0].sorted().map { items[$0].id } }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : (position[lhs[0]] ?? 0) < (position[rhs[0]] ?? 0)
            }
    }
}

public enum ThemeRanking {
    /// Themes whose members are most similar to one article. A theme's score is the mean of its (up to) three
    /// highest member similarities. `pool` must hold the article, every candidate member and the background items;
    /// it is centered here.
    public static func nearest(articleID: UUID, pool: [EmbeddedItem], candidates: [(themeID: UUID, memberIDs: [UUID])],
                               threshold: Float = SuggestionTuning.nearestThreshold,
                               limit: Int = SuggestionTuning.maximumSuggestedThemes) -> [ThemeMatch] {
        let centered = EmbeddingMath.centered(pool)
        let byID = Dictionary(centered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let article = byID[articleID] else { return [] }
        let matches = candidates.compactMap { candidate -> ThemeMatch? in
            let similarities = candidate.memberIDs.compactMap { id -> Float? in
                guard id != articleID, let member = byID[id], member.space == article.space else { return nil }
                return EmbeddingMath.cosine(article.vector, member.vector)
            }.sorted(by: >)
            guard !similarities.isEmpty else { return nil }
            let top = similarities.prefix(SuggestionTuning.nearestTopSimilarities)
            let score = top.reduce(0, +) / Float(top.count)
            return score >= threshold ? ThemeMatch(themeID: candidate.themeID, score: score) : nil
        }
        return matches.sorted { $0.score != $1.score ? $0.score > $1.score : $0.themeID.uuidString < $1.themeID.uuidString }
            .prefix(limit).map { $0 }
    }
}
