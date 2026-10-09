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
        let items = [item(0, [2, 0]), item(1, [4, 0]), item(2, [100, 100], space: "latin")]
        let centered = EmbeddingMath.centered(items)
        #expect(centered[0].vector == [-1, 0] && centered[1].vector == [1, 0])
        #expect(centered[2].vector == [0, 0])            // a space with one item has no direction left
        #expect(centered.map(\.id) == items.map(\.id))
    }

    @Test func clustersSeparateTopicsAndLeaveSingletonsAlone() {
        let items = EmbeddingMath.centered([
            item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [5, 5, 12])
        ])
        let groups = ThemeClustering.clusters(of: items, threshold: SuggestionTuning.clusterThreshold)
        #expect(indices(groups) == [[0, 1], [2, 3], [4]])
    }

    @Test func clustersAreDeterministicOrderedBySizeThenPosition() {
        let items = EmbeddingMath.centered([
            item(0, [0, 10, 1]), item(1, [10, 1, 0]), item(2, [10, 0, 1]), item(3, [1, 10, 0]), item(4, [10, 1, 1])
        ])
        let first = indices(ThemeClustering.clusters(of: items, threshold: 0.15))
        #expect(first == [[1, 2, 4], [0, 3]])             // larger first; members keep input order
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
        let items = EmbeddingMath.centered([item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1])])
        #expect(ThemeClustering.clusters(of: items, threshold: 1.1).count == 3)
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
        let pool = [item(0, [10, 1, 0]), item(1, [10, 0, 1], space: "latin"), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [-9, -9, 9])]
        #expect(ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(theme, [ids[0], ids[1], UUID()])]).isEmpty)
        #expect(ThemeRanking.nearest(articleID: UUID(), pool: pool, candidates: [(theme, [ids[2]])]).isEmpty)
        #expect(ThemeRanking.nearest(articleID: ids[0], pool: [], candidates: [(theme, [ids[2]])]).isEmpty)
    }

    @Test func nearestBreaksScoreTiesByThemeID() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let pool = [item(0, [10, 1, 0]), item(1, [10, 1, 0]), item(2, [-5, 4, 4]), item(3, [-5, -4, -4])]
        let matches = ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(b, [ids[1]]), (a, [ids[1]])], threshold: -1)
        #expect(matches.map(\.themeID) == [a, b])
    }
}
