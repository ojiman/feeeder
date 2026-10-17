import Foundation
import Testing
@testable import ReaderCore

struct ListInsertionTests {
    private func ids(_ count: Int) -> [UUID] { (0..<count).map { _ in UUID() } }

    @Test func newItemsAreFoundWhereTheyLand() {
        let old = ids(5), added = ids(3)
        #expect(ListInsertion.insertedIndexes(old: old, new: added + old) == IndexSet(0..<3))               // in front
        #expect(ListInsertion.insertedIndexes(old: old, new: Array(old[0..<2]) + added + Array(old[2...])) == IndexSet(2..<5))   // in the middle
        #expect(ListInsertion.insertedIndexes(old: old, new: old + added) == IndexSet(5..<8))               // at the end
        #expect(ListInsertion.insertedIndexes(old: old, new: [added[0], old[0], old[1], added[1]] + Array(old[2...]))
                == IndexSet([0, 3]))                                                                       // in several places
    }
    @Test func manyNewItemsAreStillAnInsertion() {
        let old = ids(3)
        #expect(ListInsertion.insertedIndexes(old: old, new: ids(500) + old)?.count == 500)
    }
    @Test func anythingElseIsNotAnInsertion() {
        let old = ids(5), added = ids(2)
        #expect(ListInsertion.insertedIndexes(old: old, new: old) == nil)                                    // no change
        #expect(ListInsertion.insertedIndexes(old: old, new: Array(old.dropFirst())) == nil)                 // removal
        #expect(ListInsertion.insertedIndexes(old: old, new: added + Array(old.dropFirst())) == nil)         // added and removed
        #expect(ListInsertion.insertedIndexes(old: old, new: added + old.reversed()) == nil)                 // reorder
        #expect(ListInsertion.insertedIndexes(old: old, new: added) == nil)                                  // replaced
    }
    @Test func anEmptyOldListIsTheFirstLoadNotAnInsertion() {
        #expect(ListInsertion.insertedIndexes(old: [], new: ids(3)) == nil)
    }
}
