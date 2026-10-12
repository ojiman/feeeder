import Foundation

public struct OPMLImportResult: Sendable {
    /// The subscriptions that were created, in the order of the file.
    public let addedFeedIDs: [UUID]
    /// Feeds of the file that the library already had (they are left as they are, folder included).
    public let alreadySubscribed: Int
}

extension ReaderStore {
    /// Adds the subscriptions of an OPML file in one save (decision 0039). A subscription that already exists is not
    /// touched. The new ones have no articles yet; the next refresh brings them. If the save fails, nothing is added.
    public func importSubscriptions(_ opmlFeeds: [OPMLFeed]) throws -> OPMLImportResult {
        try reloadIfNeeded()
        var known = Set(feeds.compactMap { $0.sourceURL.flatMap { ArticleURL.validated($0)?.absoluteString } })
        var created: [Feed] = []
        var existing = 0
        for item in opmlFeeds {
            guard known.insert(item.url.absoluteString).inserted else { existing += 1; continue }
            let feed = Feed(title: item.title, symbol: "dot.radiowaves.left.and.right")
            feed.sourceURL = item.url.absoluteString
            feed.siteURL = item.siteURL?.absoluteString
            feed.folder = SingleLineText.name(item.folder)
            context.insert(feed)
            created.append(feed)
        }
        let ids = created.map(\.id)
        guard !created.isEmpty else { return OPMLImportResult(addedFeedIDs: [], alreadySubscribed: existing) }
        try save()
        try reload()
        return OPMLImportResult(addedFeedIDs: ids, alreadySubscribed: existing)
    }
}
