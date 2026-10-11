import Foundation
import Testing
@testable import ReaderCore

struct ListInsertionTests {
    private func ids(_ count: Int) -> [UUID] { (0..<count).map { _ in UUID() } }

    @Test func newItemsInFrontOfTheOldListAreCounted() {
        let old = ids(5), added = ids(3)
        #expect(ListInsertion.leadingCount(old: old, new: added + old) == 3)
        #expect(ListInsertion.leadingCount(old: old, new: [added[0]] + old) == 1)
    }
    @Test func anythingElseIsNotALeadingInsertion() {
        let old = ids(5), added = ids(2)
        #expect(ListInsertion.leadingCount(old: old, new: old) == nil)                             // no change
        #expect(ListInsertion.leadingCount(old: old, new: old + added) == nil)                     // added at the end
        #expect(ListInsertion.leadingCount(old: old, new: Array(old[0..<2]) + added + Array(old[2...])) == nil)   // in the middle
        #expect(ListInsertion.leadingCount(old: old, new: Array(old.dropFirst())) == nil)          // removal
        #expect(ListInsertion.leadingCount(old: old, new: added + old.reversed()) == nil)          // reorder
        #expect(ListInsertion.leadingCount(old: old, new: added) == nil)                           // replaced
    }
    @Test func anEmptyOldListIsTheFirstLoadNotAnInsertion() {
        #expect(ListInsertion.leadingCount(old: [], new: ids(3)) == nil)
    }
    @Test func tooManyNewItemsAreNotAnimated() {
        let old = ids(3)
        #expect(ListInsertion.leadingCount(old: old, new: ids(20) + old) == 20)
        #expect(ListInsertion.leadingCount(old: old, new: ids(21) + old) == nil)
        #expect(ListInsertion.leadingCount(old: old, new: ids(5) + old, limit: 4) == nil)
    }
}
