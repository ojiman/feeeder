import Foundation
import SwiftData

@Model public final class Feed {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var symbol: String
    public init(title: String, symbol: String) {
        id = UUID(); self.title = title; self.symbol = symbol
    }
}

@Model public final class Article {
    @Attribute(.unique) public var id: UUID
    public var feedID: UUID
    public var title: String
    public var summary: String
    public var publisher: String
    public var publishedAt: Date
    public var isRead: Bool
    public init(feedID: UUID, title: String, summary: String, publisher: String, publishedAt: Date) {
        id = UUID(); self.feedID = feedID; self.title = title; self.summary = summary
        self.publisher = publisher; self.publishedAt = publishedAt; isRead = false
    }
}

@Model public final class ContentSnapshot {
    @Attribute(.unique) public var articleID: UUID
    public var text: String
    public init(articleID: UUID, text: String) { self.articleID = articleID; self.text = text }
}

@Model public final class SavedLike {
    @Attribute(.unique) public var articleID: UUID
    public var publisher: String
    public var likedAt: Date
    public init(article: Article, likedAt: Date) {
        articleID = article.id; publisher = article.publisher; self.likedAt = likedAt
    }
}
