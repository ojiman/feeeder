import Foundation

public struct OPMLImportResult: Sendable {
    /// The subscriptions that were created, in the order of the list.
    public let addedFeedIDs: [UUID]
    /// Feeds of the list that the library already had (they are left as they are, folder included).
    public let alreadySubscribed: Int
    /// Items whose address cannot be used (not `http(s)`, or with a user name or password).
    public let rejected: Int
    /// The subscriptions were saved, but loading the list again failed. They are there after the next successful reload.
    public let listRefreshFailed: Bool
}

extension ReaderStore {
    /// Adds the subscriptions of an OPML file in one save (decision 0041). A subscription that already exists is not
    /// touched. The new ones have no articles yet; the next refresh brings them. If the save fails, nothing is added.
    /// Addresses are normalized here as everywhere (host in lower case, no fragment), whoever calls.
    public func importSubscriptions(_ opmlFeeds: [OPMLFeed]) throws -> OPMLImportResult {
        try reloadIfNeeded()
        var known = Set(feeds.compactMap { $0.sourceURL.flatMap { ArticleURL.validated($0)?.absoluteString } })
        var created: [Feed] = []
        var existing = 0, rejected = 0
        for item in opmlFeeds {
            guard let url = ArticleURL.validated(item.url.absoluteString) else { rejected += 1; continue }
            guard known.insert(url.absoluteString).inserted else { existing += 1; continue }
            let feed = Feed(title: item.title, symbol: "dot.radiowaves.left.and.right")
            feed.sourceURL = url.absoluteString
            feed.siteURL = item.siteURL.flatMap { ArticleURL.validated($0.absoluteString) }?.absoluteString
            feed.folder = SingleLineText.name(item.folder)
            context.insert(feed)
            created.append(feed)
        }
        let ids = created.map(\.id)
        guard !created.isEmpty else { return OPMLImportResult(addedFeedIDs: [], alreadySubscribed: existing, rejected: rejected, listRefreshFailed: false) }
        try save()
        // From here the subscriptions exist. A failed reload leaves the store asking for a reload before its next change.
        var refreshFailed = false
        do { try reload() } catch { refreshFailed = true }
        return OPMLImportResult(addedFeedIDs: ids, alreadySubscribed: existing, rejected: rejected, listRefreshFailed: refreshFailed)
    }
}
