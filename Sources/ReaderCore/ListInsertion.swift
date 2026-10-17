import Foundation

/// Decides whether a change of the article list is "new articles arrived", the only change that is animated.
public enum ListInsertion {
    /// Where new items landed in `new`, when `new` is all of `old` in the same order with items put in anywhere.
    /// Nil for anything else (first load, no change, removal, reorder, replacement). Linear in the length of the lists.
    public static func insertedIndexes(old: [UUID], new: [UUID]) -> IndexSet? {
        guard !old.isEmpty, new.count > old.count else { return nil }
        let known = Set(old)
        var inserted = IndexSet(), next = 0
        for (index, id) in new.enumerated() {
            if next < old.count, id == old[next] { next += 1 }
            else if known.contains(id) { return nil }                       // an old item out of its order
            else { inserted.insert(index) }
        }
        return next == old.count ? inserted : nil
    }
}
