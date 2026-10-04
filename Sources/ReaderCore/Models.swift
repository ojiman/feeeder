import Foundation
import SwiftData

@Model public final class Feed {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var symbol: String
    public var sourceURL: String?
    public var folder: String = ""
    public var customTitle: Bool = false
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
    public var firstReceivedAt: Date
    public var firstReadAt: Date?
    public var contentDeletedAt: Date?
    public var isRead: Bool
    public var originalURL: String?
    public var identityKey: String?
    public init(feedID: UUID, title: String, summary: String, publisher: String, publishedAt: Date, receivedAt: Date = .now) {
        id = UUID(); self.feedID = feedID; self.title = title; self.summary = summary
        self.publisher = publisher; self.publishedAt = publishedAt; firstReceivedAt = receivedAt; isRead = false
    }
}

@Model public final class FeedMembership {
    @Attribute(.unique) public var key: String
    public var feedID: UUID
    public var articleID: UUID
    public var sourceID: String
    public init(feedID: UUID, articleID: UUID, sourceID: String) {
        self.feedID = feedID; self.articleID = articleID; self.sourceID = sourceID
        key = feedID.uuidString + ":" + articleID.uuidString
    }
}

@Model public final class ContentSnapshot {
    @Attribute(.unique) public var articleID: UUID
    public var text: String
    public var coverageRaw: String
    public init(articleID: UUID, text: String, coverage: ContentCoverage = .feedProvided) {
        self.articleID = articleID; self.text = text; coverageRaw = coverage.rawValue
    }
}
