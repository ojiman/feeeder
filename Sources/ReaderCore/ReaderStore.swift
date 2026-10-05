import Foundation
import Observation
import SwiftData

@Observable @MainActor public final class ReaderStore {
    public private(set) var articles: [Article] = []
    public private(set) var feeds: [Feed] = []
    public private(set) var contentRevision = 0
    public private(set) var settings: ReaderSettings?
    public var retentionDays: Int { settings?.retentionDays ?? 30 }
    @ObservationIgnored public var onContentPolicyChanged: (@MainActor () -> Void)?
    public private(set) var weeks: [WeeklyPeriod] = []
    public private(set) var notes: [WeeklyNote] = []
    public private(set) var noteSources: [NoteSource] = []
    public private(set) var memberships: [FeedMembership] = []
    private var membershipIndex: [UUID: Set<UUID>] = [:]
    @ObservationIgnored private var articleIndex: [UUID: Article] = [:]
    @ObservationIgnored private var feedIndex: [UUID: Feed] = [:]
    @ObservationIgnored private var feedArticles: [UUID: [Article]] = [:]
    @ObservationIgnored private var articleFeeds: [UUID: Set<UUID>] = [:]
    public private(set) var articleIDs: [UUID] = []
    @ObservationIgnored private var feedArticleIDs: [UUID: [UUID]] = [:]
    @ObservationIgnored private var unreadIDs: Set<UUID> = []
    public private(set) var unreadCount = 0
    public private(set) var feedUnreadCounts: [UUID: Int] = [:]
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored let context: ModelContext

    public convenience init(url: URL, seedDemo: Bool = false, now: Date = .now) throws {
        let schema = Schema([Feed.self, Article.self, ContentSnapshot.self, FeedMembership.self, WeeklyPeriod.self, WeeklyNote.self, NoteSource.self, ReaderSettings.self])
        let configuration = ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try self.init(container: container, seedDemo: seedDemo, now: now)
    }

    init(container: ModelContainer, seedDemo: Bool = false, now: Date = .now) throws {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        if try context.fetchCount(FetchDescriptor<ReaderSettings>()) == 0 {
            context.insert(ReaderSettings()); try context.save()
        }
        if seedDemo { try seedIfEmpty(now: now) }
        else { try reload() }
        try purgeExpired(at: now)
    }

    public func seedIfEmpty(now: Date = .now) throws {
        if try context.fetchCount(FetchDescriptor<Article>()) == 0 {
            DemoLibrary.insert(into: context, at: now)
            try save()
        }
        try reload()
    }

    func reload() throws {
        contentRevision += 1
        settings = try context.fetch(FetchDescriptor<ReaderSettings>()).first
        articles = try context.fetch(FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]))
        feeds = try context.fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.title)]))
        weeks = try context.fetch(FetchDescriptor<WeeklyPeriod>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        notes = try context.fetch(FetchDescriptor<WeeklyNote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        noteSources = try context.fetch(FetchDescriptor<NoteSource>())
        memberships = try context.fetch(FetchDescriptor<FeedMembership>())
        membershipIndex = [:]
        for membership in memberships { membershipIndex[membership.feedID, default: []].insert(membership.articleID) }
        articleIndex = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
        feedIndex = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
        feedArticles = [:]
        articleFeeds = [:]
        for membership in memberships { articleFeeds[membership.articleID, default: []].insert(membership.feedID) }
        for article in articles {
            for feedID in articleFeeds[article.id] ?? [] { feedArticles[feedID, default: []].append(article) }
        }
        articleIDs = articles.map(\.id)
        feedArticleIDs = feedArticles.mapValues { $0.map(\.id) }
        refreshUnreadCounts()
    }

    public func article(id: UUID) -> Article? { articleIndex[id] }
    public func feed(id: UUID) -> Feed? { feedIndex[id] }
    public func visibleArticles(feedID: UUID?, unreadOnly: Bool, keeping: UUID?) -> [Article] {
        visibleArticleIDs(feedID: feedID, unreadOnly: unreadOnly, keeping: keeping).compactMap { articleIndex[$0] }
    }
    public func visibleArticleIDs(feedID: UUID?, unreadOnly: Bool, keeping: UUID?) -> [UUID] {
        // Observe one array/count rather than registering every SwiftData Article.id getter.
        let all = articleIDs
        let values = feedID.map { feedArticleIDs[$0] ?? [] } ?? all
        guard unreadOnly else { return values }
        _ = unreadCount
        return values.filter { unreadIDs.contains($0) || $0 == keeping }
    }
    private func refreshUnreadCounts() {
        unreadCount = articles.filter { !$0.isRead }.count
        unreadIDs = Set(articles.filter { !$0.isRead }.map(\.id))
        feedUnreadCounts = feedArticles.mapValues { $0.filter { !$0.isRead }.count }
    }
    private func updateUnreadCounts(_ article: Article, wasRead: Bool) {
        guard article.isRead != wasRead else { return }
        let delta = article.isRead ? -1 : 1
        unreadCount += delta
        if article.isRead { unreadIDs.remove(article.id) } else { unreadIDs.insert(article.id) }
        for id in articleFeeds[article.id] ?? [] { feedUnreadCounts[id, default: 0] += delta }
    }

    public func isArticle(_ article: Article, in feedID: UUID) -> Bool {
        membershipIndex[feedID]?.contains(article.id) == true
    }

    @discardableResult public func importFeed(_ parsed: ParsedFeed, receivedAt: Date = .now) throws -> Feed {
        let feed = feeds.first { $0.sourceURL == parsed.sourceURL.absoluteString } ?? Feed(title: parsed.title, symbol: "dot.radiowaves.left.and.right")
        context.insert(feed)
        feed.sourceURL = parsed.sourceURL.absoluteString
        if !feed.customTitle { feed.title = parsed.title }
        do {
            var contentRemoved = false
            var allArticles = articles
            var allMemberships = memberships
            for entry in parsed.entries {
                let identity = entry.url?.absoluteString ?? (parsed.sourceURL.absoluteString + "|" + entry.sourceID)
                let priorID = allMemberships.first { $0.feedID == feed.id && $0.sourceID == entry.sourceID }?.articleID
                let existing = allArticles.first { $0.identityKey == identity } ?? allArticles.first { $0.id == priorID }
                let article = existing ?? Article(feedID: feed.id, title: entry.title, summary: entry.summary,
                                                  publisher: entry.url?.host ?? "掲載サイト不明", publishedAt: entry.publishedAt ?? .distantPast, receivedAt: receivedAt)
                if existing == nil { context.insert(article); allArticles.append(article) }
                if let url = entry.url {
                    article.identityKey = identity
                    article.originalURL = url.absoluteString
                } else if article.identityKey == nil { article.identityKey = identity }
                article.title = entry.title
                let available = isContentAvailable(article, at: receivedAt)
                if available { article.summary = entry.summary }
                else { contentRemoved = try removeContent(articleIDs: [article.id], at: receivedAt) || contentRemoved }
                if let date = entry.publishedAt { article.publishedAt = date }
                // A second feed must not overwrite a saved article with a shorter excerpt.
                let id = article.id
                if available, let snapshot = try context.fetch(FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == id })).first {
                    if !entry.body.isEmpty &&
                        snapshot.coverageRaw != ContentCoverage.extracted.rawValue &&
                        (article.feedID == feed.id || entry.body.count > snapshot.text.count) { snapshot.text = entry.body; snapshot.coverageRaw = entry.coverage.rawValue }
                } else if available && !entry.body.isEmpty { context.insert(ContentSnapshot(articleID: id, text: entry.body, coverage: entry.coverage)) }
                if !allMemberships.contains(where: { $0.feedID == feed.id && $0.articleID == id }) {
                    let membership = FeedMembership(feedID: feed.id, articleID: id, sourceID: entry.sourceID)
                    context.insert(membership); allMemberships.append(membership)
                }
            }
            try save()
            try reload()
            if contentRemoved { onContentPolicyChanged?() }
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
        // Keep articles and bodies. Subscription removal is not article deletion.
        try save(); try reload()
    }

    public func body(for article: Article, at: Date = .now) -> String? {
        try? content(articleID: article.id, at: at)?.text
    }

    public func setRead(_ article: Article, _ value: Bool) throws {
        guard article.isRead != value else { return }
        let wasRead = article.isRead
        article.isRead = value
        try save()
        updateUnreadCounts(article, wasRead: wasRead)
    }

    public func saveExtractedContent(articleID: UUID, result: ExtractionResult, at: Date) throws {
        guard result.coverage == .extracted, !result.text.isEmpty,
              let article = articles.first(where: { $0.id == articleID }), isContentAvailable(article, at: at) else { return }
        let request = FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == articleID })
        if let snapshot = try context.fetch(request).first { snapshot.text = result.text; snapshot.coverageRaw = result.coverage.rawValue }
        else { context.insert(ContentSnapshot(articleID: articleID, text: result.text, coverage: result.coverage)) }
        try save(); try reload()
    }

    public func content(articleID: UUID, at: Date) throws -> ArticleContent? {
        guard let article = articleIndex[articleID], isContentAvailable(article, at: at) else { return nil }
        let request = FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == articleID })
        let snapshot = try context.fetch(request).first
        let body = snapshot?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summary = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || !summary.isEmpty else { return nil }
        return ArticleContent(articleID: articleID, text: body.isEmpty ? summary : body, summary: summary,
                              coverage: body.isEmpty ? .summaryOnly : ContentCoverage(rawValue: snapshot?.coverageRaw ?? "") ?? .unavailable,
                              originalURL: article.originalURL.flatMap { ArticleURL.validated($0) })
    }

    public func markDisplayed(articleID: UUID, at: Date) throws {
        guard let article = articleIndex[articleID],
              try content(articleID: articleID, at: at) != nil else { return }
        guard !article.isRead || article.firstReadAt == nil else { return }
        let wasRead = article.isRead
        article.isRead = true
        if article.firstReadAt == nil { article.firstReadAt = at }
        try save()
        updateUnreadCounts(article, wasRead: wasRead)
    }

    func save() throws {
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
