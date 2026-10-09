import Foundation
import Testing
@testable import ReaderCore

struct ThemeClusteringTests {
    let ids = (0..<10).map { _ in UUID() }
    func item(_ index: Int, _ vector: [Float], space: String = "ja") -> EmbeddedItem {
        EmbeddedItem(id: ids[index], space: space, vector: vector)
    }
    func indices(_ groups: [[UUID]]) -> [[Int]] { groups.map { $0.map { id in ids.firstIndex(of: id)! } } }

    @Test func cosineHandlesMismatchedEmptyAndZeroVectors() {
        #expect(EmbeddingMath.cosine([1, 0], [1, 0]) == 1)
        #expect(EmbeddingMath.cosine([1, 0], [0, 1]) == 0)
        #expect(EmbeddingMath.cosine([1, 0], [-1, 0]) == -1)
        #expect(EmbeddingMath.cosine([1, 0], [1]) == nil)
        #expect(EmbeddingMath.cosine([], []) == nil)
        #expect(EmbeddingMath.cosine([0, 0], [1, 1]) == nil)
    }

    @Test func centeringSubtractsEachSpacesOwnMean() {
        let japanese = (0..<SuggestionTuning.minimumItemsPerSpace).map { item($0 % ids.count, [Float($0), 0], space: "ja") }
        let items = japanese + [item(9, [100, 100], space: "latin")]
        let centered = EmbeddingMath.centered(items)
        let mean = Float(SuggestionTuning.minimumItemsPerSpace - 1) / 2
        #expect(centered.count == japanese.count)                                   // a space too small to average is left out
        #expect(centered.map(\.vector[0]) == (0..<japanese.count).map { Float($0) - mean })
        #expect(centered.allSatisfy { $0.space == "ja" })
    }

    @Test func aSpaceWithTooFewItemsIsLeftOutRatherThanCenteredIntoNoise() {
        // With n items, centered vectors sum to zero: n = 2 gives cosine -1 for every pair. Fewer than the minimum is dropped.
        let few = (0..<(SuggestionTuning.minimumItemsPerSpace - 1)).map { item($0, [Float($0 + 1), 1]) }
        #expect(EmbeddingMath.centered(few).isEmpty)
        #expect(ThemeClustering.clusters(of: EmbeddingMath.centered(few), threshold: 0.15).isEmpty)
    }

    @Test func clustersSeparateTopicsAndLeaveSingletonsAlone() {
        let items = EmbeddingMath.centered([
            item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [5, 5, 12]), item(5, [5, 5, 12])
        ])
        let groups = ThemeClustering.clusters(of: items, threshold: SuggestionTuning.clusterThreshold)
        #expect(indices(groups) == [[0, 1], [2, 3], [4, 5]])
    }

    @Test func clustersAreDeterministicOrderedBySizeThenPosition() {
        let items = EmbeddingMath.centered([
            item(0, [0, 10, 1]), item(1, [10, 1, 0]), item(2, [10, 0, 1]), item(3, [1, 10, 0]), item(4, [10, 1, 1]), item(5, [1, 1, 10])
        ])
        let first = indices(ThemeClustering.clusters(of: items, threshold: 0.15))
        #expect(first == [[1, 2, 4], [0, 3], [5]])             // larger first; members keep input order
        #expect(first == indices(ThemeClustering.clusters(of: items, threshold: 0.15)))
    }

    @Test func differentSpacesNeverMergeAndDegenerateInputIsSafe() {
        let mixed = [item(0, [1, 0], space: "ja"), item(1, [1, 0], space: "latin")]
        #expect(indices(ThemeClustering.clusters(of: mixed, threshold: -1)) == [[0], [1]])
        #expect(ThemeClustering.clusters(of: [], threshold: 0.15).isEmpty)
        #expect(indices(ThemeClustering.clusters(of: [item(0, [1, 0])], threshold: 0.15)) == [[0]])
        #expect(indices(ThemeClustering.clusters(of: [item(0, [0, 0]), item(1, [0, 0])], threshold: 0.15)) == [[0], [1]])
    }

    @Test func aHighThresholdKeepsEverythingApart() {
        let items = EmbeddingMath.centered([item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [5, 5, 12]), item(5, [3, 3, 9])])
        #expect(ThemeClustering.clusters(of: items, threshold: 1.1).count == 6)
    }

    @Test func nearestRanksThemesByTheirClosestMembersAndHonorsThresholdAndLimit() {
        let finance = UUID(), cooking = UUID(), empty = UUID()
        let pool = [item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1]), item(3, [1, 10, 0]),
                    item(4, [5, 5, 12]), item(5, [-6, -6, 6]), item(6, [-8, 4, -4])]
        let matches = ThemeRanking.nearest(articleID: ids[0], pool: pool,
            candidates: [(cooking, [ids[2], ids[3]]), (finance, [ids[1]]), (empty, [])])
        #expect(matches.map(\.themeID) == [finance])      // cooking is below the threshold, the empty theme has no members
        #expect(matches[0].score > SuggestionTuning.nearestThreshold)
        let limited = ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(cooking, [ids[2]]), (finance, [ids[1]])],
                                           threshold: -1, limit: 1)
        #expect(limited.map(\.themeID) == [finance])
    }

    @Test func nearestSkipsTheArticleItselfAndOtherSpacesAndUnknownIDs() {
        let theme = UUID()
        let pool = [item(0, [10, 1, 0]), item(1, [10, 0, 1], space: "latin"), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [-9, -9, 9]),
                    item(5, [-3, 6, -9]), item(6, [4, -7, 2])]
        #expect(ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(theme, [ids[0], ids[1], UUID()])]).isEmpty)
        #expect(ThemeRanking.nearest(articleID: UUID(), pool: pool, candidates: [(theme, [ids[2]])]).isEmpty)
        #expect(ThemeRanking.nearest(articleID: ids[0], pool: [], candidates: [(theme, [ids[2]])]).isEmpty)
    }

    @Test func nearestBreaksScoreTiesByThemeID() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let pool = [item(0, [10, 1, 0]), item(1, [10, 1, 0]), item(2, [-5, 4, 4]), item(3, [-5, -4, -4]), item(4, [2, 7, -3]), item(5, [-6, 1, 8])]
        let matches = ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(b, [ids[1]]), (a, [ids[1]])], threshold: -1)
        #expect(matches.map(\.themeID) == [a, b])
    }
}
