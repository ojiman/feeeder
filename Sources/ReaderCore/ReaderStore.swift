import Foundation
import Observation
import SwiftData

@Observable @MainActor public final class ReaderStore {
    public private(set) var articles: [Article] = []
    public private(set) var feeds: [Feed] = []
    public private(set) var likes: [SavedLike] = []
    public private(set) var memberships: [FeedMembership] = []
    private var likeIndex: [UUID: SavedLike] = [:]
    private var membershipIndex: [UUID: Set<UUID>] = [:]
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let context: ModelContext

    public init(url: URL) throws {
        let schema = Schema([Feed.self, Article.self, ContentSnapshot.self, SavedLike.self, FeedMembership.self])
        let configuration = ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
        try seedIfEmpty()
    }

    public func seedIfEmpty() throws {
        if try context.fetchCount(FetchDescriptor<Article>()) == 0 {
            DemoLibrary.insert(into: context)
            try context.save()
        }
        try reload()
        // Add memberships for the pre-import prototype. Removed subscriptions have no Feed,
        // so reopening cannot accidentally restore an unsubscribed membership.
        let feedIDs = Set(feeds.map(\.id))
        for article in articles where article.identityKey == nil && feedIDs.contains(article.feedID) {
            if !isArticle(article, in: article.feedID) {
                context.insert(FeedMembership(feedID: article.feedID, articleID: article.id, sourceID: article.id.uuidString))
            }
        }
        try context.save()
        try reload()
    }

    private func reload() throws {
        articles = try context.fetch(FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]))
        feeds = try context.fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.title)]))
        likes = try context.fetch(FetchDescriptor<SavedLike>())
        memberships = try context.fetch(FetchDescriptor<FeedMembership>())
        membershipIndex = [:]
        for membership in memberships { membershipIndex[membership.feedID, default: []].insert(membership.articleID) }
        likeIndex = Dictionary(uniqueKeysWithValues: likes.map { ($0.articleID, $0) })
    }

    public func like(for article: Article) -> SavedLike? { likeIndex[article.id] }

    public func isArticle(_ article: Article, in feedID: UUID) -> Bool {
        membershipIndex[feedID]?.contains(article.id) == true
    }

    @discardableResult public func importFeed(_ parsed: ParsedFeed) throws -> Feed {
        let feed = feeds.first { $0.sourceURL == parsed.sourceURL.absoluteString } ?? Feed(title: parsed.title, symbol: "dot.radiowaves.left.and.right")
        context.insert(feed)
        feed.sourceURL = parsed.sourceURL.absoluteString
        if !feed.customTitle { feed.title = parsed.title }
        do {
            var allArticles = articles
            var allMemberships = memberships
            for entry in parsed.entries {
                let identity = entry.url?.absoluteString ?? (parsed.sourceURL.absoluteString + "|" + entry.sourceID)
                let priorID = allMemberships.first { $0.feedID == feed.id && $0.sourceID == entry.sourceID }?.articleID
                let existing = allArticles.first { $0.identityKey == identity } ?? allArticles.first { $0.id == priorID }
                let article = existing ?? Article(feedID: feed.id, title: entry.title, summary: entry.summary,
                                                  publisher: entry.url?.host ?? "掲載サイト不明", publishedAt: entry.publishedAt ?? .distantPast)
                if existing == nil { context.insert(article); allArticles.append(article) }
                if let url = entry.url {
                    article.identityKey = identity
                    article.originalURL = url.absoluteString
                } else if article.identityKey == nil { article.identityKey = identity }
                article.title = entry.title
                article.summary = entry.summary
                if let date = entry.publishedAt { article.publishedAt = date }
                // A second feed must not overwrite a saved article with a shorter excerpt.
                let id = article.id
                if let snapshot = try context.fetch(FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == id })).first {
                    if like(for: article) == nil && !entry.body.isEmpty &&
                        (article.feedID == feed.id || entry.body.count > snapshot.text.count) { snapshot.text = entry.body }
                } else { context.insert(ContentSnapshot(articleID: id, text: entry.body)) }
                if !allMemberships.contains(where: { $0.feedID == feed.id && $0.articleID == id }) {
                    let membership = FeedMembership(feedID: feed.id, articleID: id, sourceID: entry.sourceID)
                    context.insert(membership); allMemberships.append(membership)
                }
            }
            try save()
            try reload()
            return feed
        } catch { context.rollback(); try? reload(); throw error }
    }

    public func updateSubscription(_ feed: Feed, title: String, folder: String) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw FeedImportError.missingTitle }
        feed.title = title; feed.folder = folder.trimmingCharacters(in: .whitespacesAndNewlines); feed.customTitle = true
        try save(); try reload()
    }

    public func unsubscribe(_ feed: Feed) throws {
        for membership in memberships where membership.feedID == feed.id { context.delete(membership) }
        context.delete(feed)
        // Keep articles, bodies and likes. Subscription removal is not article deletion.
        try save(); try reload()
    }

    public func body(for article: Article) -> String? {
        let id = article.id
        let request = FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == id })
        return try? context.fetch(request).first?.text
    }

    public func setRead(_ article: Article, _ value: Bool) throws {
        guard article.isRead != value else { return }
        article.isRead = value
        try save()
    }

    public func toggleLike(_ article: Article, at date: Date = .now) throws {
        if let existing = like(for: article) {
            context.delete(existing)
            try save()
            likes.removeAll { $0.articleID == article.id }
            likeIndex.removeValue(forKey: article.id)
        } else {
            let savedLike = SavedLike(article: article, likedAt: date)
            context.insert(savedLike)
            try save()
            likes.append(savedLike)
            likeIndex[article.id] = savedLike
        }
    }

    private func save() throws {
        do { try context.save() }
        catch { context.rollback(); try? reload(); throw error }
    }
}

public enum ReaderNavigation {
    public static func move(_ selected: UUID?, by offset: Int, in ids: [UUID]) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let selected, let index = ids.firstIndex(of: selected) else { return ids.first }
        return ids[min(max(0, index + offset), ids.count - 1)]
    }
}
