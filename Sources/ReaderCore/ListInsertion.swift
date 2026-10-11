import Foundation

/// Decides whether a change of the article list is "new articles arrived at the top", the only change that is animated.
public enum ListInsertion {
    /// How many items were put in front of `old`, when `new` is exactly those items followed by all of `old`, in the same order.
    /// Nil for anything else (first load, no change, removal, reorder, insertion elsewhere) and for more than `limit` items:
    /// a long list of new items would only move the old rows far off screen.
    public static func leadingCount(old: [UUID], new: [UUID], limit: Int = 20) -> Int? {
        let count = new.count - old.count
        guard !old.isEmpty, (1...limit).contains(count), new.suffix(old.count).elementsEqual(old) else { return nil }
        return count
    }
}
