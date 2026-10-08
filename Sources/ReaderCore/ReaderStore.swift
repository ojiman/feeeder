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
    public private(set) var dailyNotes: [DailyNote] = []
    public private(set) var scraps: [NoteScrap] = []
    public private(set) var starCount = 0
    @ObservationIgnored var starredIDs: Set<UUID> = []
    @ObservationIgnored private var articleIndex: [UUID: Article] = [:]
    @ObservationIgnored private var feedIndex: [UUID: Feed] = [:]
    @ObservationIgnored private var feedArticles: [UUID: [Article]] = [:]
    @ObservationIgnored private var articleFeeds: [UUID: Set<UUID>] = [:]
    public private(set) var articleIDs: [UUID] = []
    @ObservationIgnored private var feedArticleIDs: [UUID: [UUID]] = [:]
    @ObservationIgnored var folderIndex: [String: [UUID]] = [:]
    public private(set) var folderUnreadCounts: [String: Int] = [:]
    @ObservationIgnored private var unreadIDs: Set<UUID> = []
    public private(set) var unreadCount = 0
    public private(set) var feedUnreadCounts: [UUID: Int] = [:]
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored var context: ModelContext
    @ObservationIgnored private var saveHook: (() throws -> Void)?
    @ObservationIgnored private var reloadHook: (() throws -> Void)?
    @ObservationIgnored private var needsReload = false

    public static var schema: Schema {
        Schema([Feed.self, Article.self, ContentSnapshot.self, FeedMembership.self, WeeklyPeriod.self,
                WeeklyNote.self, NoteSource.self, ReaderSettings.self, DailyNote.self, NoteScrap.self])
    }

    public convenience init(url: URL, seedDemo: Bool = false, now: Date = .now) throws {
        let schema = Self.schema
        let configuration = ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try self.init(container: container, seedDemo: seedDemo, now: now)
    }

    init(container: ModelContainer, seedDemo: Bool = false, now: Date = .now,
         saveHook: (() throws -> Void)? = nil, reloadHook: (() throws -> Void)? = nil) throws {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        if try context.fetchCount(FetchDescriptor<ReaderSettings>()) == 0 {
            context.insert(ReaderSettings()); try context.save()
        }
        if seedDemo { try seedIfEmpty(now: now) }
        else { try reload() }
        try purgeExpired(at: now)
        self.saveHook = saveHook
        self.reloadHook = reloadHook
    }

    public func seedIfEmpty(now: Date = .now) throws {
        try reloadIfNeeded()
        if try context.fetchCount(FetchDescriptor<Article>()) == 0 {
            DemoLibrary.insert(into: context, at: now)
            try save()
        }
        try reload()
    }

    func reload() throws {
        needsReload = true
        try reloadHook?()
        contentRevision += 1
        settings = try context.fetch(FetchDescriptor<ReaderSettings>()).first
        articles = try context.fetch(FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]))
        feeds = try context.fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.title)]))
        weeks = try context.fetch(FetchDescriptor<WeeklyPeriod>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        notes = try context.fetch(FetchDescriptor<WeeklyNote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        noteSources = try context.fetch(FetchDescriptor<NoteSource>())
        memberships = try context.fetch(FetchDescriptor<FeedMembership>())
        dailyNotes = try context.fetch(FetchDescriptor<DailyNote>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        scraps = try context.fetch(FetchDescriptor<NoteScrap>(sortBy: [SortDescriptor(\.savedAt)]))
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
        folderIndex = [:]
        for article in articles {
            let folders = Set((articleFeeds[article.id] ?? []).compactMap { feedIndex[$0]?.folder })
            for folder in folders { folderIndex[folder, default: []].append(article.id) }
        }
        refreshUnreadCounts()
        refreshStarIndex()
        needsReload = false
    }

    func reloadIfNeeded() throws {
        if needsReload { try reload() }
    }

    func refreshStarIndex() {
        starredIDs = Set(articles.filter { $0.starredAt != nil }.map(\.id))
        starCount = starredIDs.count
    }

    public func article(id: UUID) -> Article? { articleIndex[id] }
    public func feed(id: UUID) -> Feed? { feedIndex[id] }
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
        folderUnreadCounts = folderIndex.mapValues { $0.filter { unreadIDs.contains($0) }.count }
    }
    private func updateUnreadCounts(_ article: Article, wasRead: Bool) {
        guard article.isRead != wasRead else { return }
        let delta = article.isRead ? -1 : 1
        unreadCount += delta
        if article.isRead { unreadIDs.remove(article.id) } else { unreadIDs.insert(article.id) }
        for id in articleFeeds[article.id] ?? [] { feedUnreadCounts[id, default: 0] += delta }
        let folders = Set((articleFeeds[article.id] ?? []).compactMap { feedIndex[$0]?.folder })
        for folder in folders { folderUnreadCounts[folder, default: 0] += delta }
    }

    @discardableResult public func importFeed(_ parsed: ParsedFeed, receivedAt: Date = .now, folder: String? = nil) throws -> Feed {
        try reloadIfNeeded()
        let feed = feeds.first { $0.sourceURL == parsed.sourceURL.absoluteString } ?? Feed(title: parsed.title, symbol: "dot.radiowaves.left.and.right")
        context.insert(feed)
        feed.sourceURL = parsed.sourceURL.absoluteString
        feed.siteURL = parsed.siteURL?.absoluteString ?? feed.siteURL
        feed.iconURL = parsed.iconURL?.absoluteString ?? feed.iconURL
        if !feed.customTitle { feed.title = parsed.title }
        do {
            if let folder { feed.folder = folder.trimmingCharacters(in: .whitespacesAndNewlines) }
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
                if available { article.summary = entry.summary; article.imageURL = entry.imageURL?.absoluteString ?? article.imageURL }
                else { contentRemoved = try removeContent(articleIDs: [article.id], at: receivedAt) || contentRemoved }
                if let date = entry.publishedAt { article.publishedAt = date }
                // A second feed must not overwrite a saved article with a shorter excerpt.
                let id = article.id
                if available, let snapshot = try context.fetch(FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == id })).first {
                    if !entry.body.isEmpty &&
                        snapshot.coverageRaw != ContentCoverage.extracted.rawValue &&
                        (article.feedID == feed.id || entry.body.count > snapshot.text.count) {
                        snapshot.text = entry.body; snapshot.coverageRaw = entry.coverage.rawValue
                        snapshot.bodyFormatData = BodyParagraph.encode(entry.bodyParagraphs)
                    }
                } else if available && !entry.body.isEmpty { context.insert(ContentSnapshot(articleID: id, text: entry.body, coverage: entry.coverage, bodyParagraphs: entry.bodyParagraphs)) }
                if !allMemberships.contains(where: { $0.feedID == feed.id && $0.articleID == id }) {
                    let membership = FeedMembership(feedID: feed.id, articleID: id, sourceID: entry.sourceID)
                    context.insert(membership); allMemberships.append(membership)
                }
            }
            try save()
            try reload()
            if contentRemoved { onContentPolicyChanged?() }
            return feed
        } catch { rollback(); throw error }
    }

    public func updateSubscription(_ feed: Feed, title: String, folder: String) throws {
        try reloadIfNeeded()
        guard let feed = self.feed(id: feed.id) else { return }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw FeedImportError.missingTitle }
        feed.title = title; feed.folder = folder.trimmingCharacters(in: .whitespacesAndNewlines); feed.customTitle = true
        try save(); try reload()
    }

    public func unsubscribe(_ feed: Feed) throws {
        try reloadIfNeeded()
        guard let feed = self.feed(id: feed.id) else { return }
        for membership in memberships where membership.feedID == feed.id { context.delete(membership) }
        context.delete(feed)
        // Keep articles and bodies. Subscription removal is not article deletion.
        try save(); try reload()
    }

    public func setRead(_ article: Article, _ value: Bool) throws {
        try reloadIfNeeded()
        guard let article = self.article(id: article.id) else { return }
        guard article.isRead != value else { return }
        let wasRead = article.isRead
        article.isRead = value
        try save()
        updateUnreadCounts(article, wasRead: wasRead)
    }

    public func saveExtractedContent(articleID: UUID, result: ExtractionResult, at: Date) throws {
        try reloadIfNeeded()
        guard result.coverage == .extracted, !result.text.isEmpty,
              let article = articles.first(where: { $0.id == articleID }), isContentAvailable(article, at: at) else { return }
        let request = FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == articleID })
        if let snapshot = try context.fetch(request).first {
            snapshot.text = result.text; snapshot.coverageRaw = result.coverage.rawValue
            snapshot.bodyFormatData = BodyParagraph.encode(result.bodyParagraphs)
        }
        else { context.insert(ContentSnapshot(articleID: articleID, text: result.text, coverage: result.coverage, bodyParagraphs: result.bodyParagraphs)) }
        try save(); try reload()
    }

    public func content(articleID: UUID, at: Date) throws -> ArticleContent? {
        try reloadIfNeeded()
        guard let article = articleIndex[articleID], isContentAvailable(article, at: at) else { return nil }
        let request = FetchDescriptor<ContentSnapshot>(predicate: #Predicate { $0.articleID == articleID })
        let snapshot = try context.fetch(request).first
        let savedBody = snapshot?.text ?? ""
        let body = savedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : savedBody
        let summary = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || !summary.isEmpty else { return nil }
        return ArticleContent(articleID: articleID, text: body.isEmpty ? summary : body, summary: summary,
                              coverage: body.isEmpty ? .summaryOnly : ContentCoverage(rawValue: snapshot?.coverageRaw ?? "") ?? .unavailable,
                              originalURL: article.originalURL.flatMap { ArticleURL.validated($0) },
                              bodyParagraphs: body.isEmpty ? nil : BodyParagraph.decode(snapshot?.bodyFormatData, matching: body))
    }

    public func markDisplayed(articleID: UUID, at: Date) throws {
        try reloadIfNeeded()
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
        // Mutations must resolve models only after recovery has loaded this context.
        guard !needsReload else { throw CocoaError(.fileReadUnknown) }
        do { try saveHook?(); try context.save() }
        catch { rollback(); throw error }
    }

    private func rollback() {
        context.rollback()
        // ContentRetentionTests.failedSaveRollsBackAndDoesNotNotify reproduces
        // changed registered models after a failed save on macOS 26.6.2 / Xcode 26.6.
        // Reload committed values using a fresh context for the same store.
        context = ModelContext(container)
        context.autosaveEnabled = false
        try? reload()
    }
}

public enum ReaderNavigation {
    public static func isForward(from: UUID?, to: UUID?, in ids: [UUID]) -> Bool {
        guard let from, let to, let old = ids.firstIndex(of: from), let new = ids.firstIndex(of: to) else { return true }
        return new >= old
    }
    public static func move(_ selected: UUID?, by offset: Int, in ids: [UUID]) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let selected, let index = ids.firstIndex(of: selected) else { return ids.first }
        return ids[min(max(0, index + offset), ids.count - 1)]
    }
}
