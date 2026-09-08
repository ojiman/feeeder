import Foundation
import Observation
import SwiftData

@Observable @MainActor public final class ReaderStore {
    public private(set) var articles: [Article] = []
    public private(set) var feeds: [Feed] = []
    public private(set) var likes: [SavedLike] = []
    private var likeIndex: [UUID: SavedLike] = [:]
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let context: ModelContext

    public init(url: URL) throws {
        let schema = Schema([Feed.self, Article.self, ContentSnapshot.self, SavedLike.self])
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
    }

    private func reload() throws {
        articles = try context.fetch(FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]))
        feeds = try context.fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.title)]))
        likes = try context.fetch(FetchDescriptor<SavedLike>())
        likeIndex = Dictionary(uniqueKeysWithValues: likes.map { ($0.articleID, $0) })
    }

    public func like(for article: Article) -> SavedLike? { likeIndex[article.id] }

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
