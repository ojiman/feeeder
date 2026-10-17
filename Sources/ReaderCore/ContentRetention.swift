import Foundation
import SwiftData

public struct RetentionPolicy: Sendable {
    public static let choices = [7, 30, 90, 365]
    public let days: Int
    public init(days: Int) { self.days = days }
    public func expiresAt(receivedAt: Date, firstReadAt: Date?) -> Date {
        (firstReadAt ?? receivedAt).addingTimeInterval(Double(days) * 86_400)
    }
}

public struct DeletionPreview: Sendable {
    public let articleIDs: [UUID]
    public let bodyCount: Int
    public let summaryCount: Int
    public let estimatedBytes: Int
}

@Model public final class ReaderSettings {
    @Attribute(.unique) public var key: String
    public var retentionDays: Int
    public init() { key = "reader"; retentionDays = 30 }
}

public enum RetentionError: LocalizedError {
    case invalidDays
    public var errorDescription: String? { String(localized: "Choose a retention period of 7, 30, 90 or 365 days.", bundle: ReaderLocalization.bundle) }
}

extension ReaderStore {
    public func isContentAvailable(_ article: Article, at: Date) -> Bool {
        article.contentDeletedAt == nil &&
        RetentionPolicy(days: retentionDays).expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt) > at
    }
    public func previewDeletion(days: Int?, at: Date) throws -> DeletionPreview {
        try reloadIfNeeded()
        let policy = RetentionPolicy(days: days ?? retentionDays)
        let candidates = articles.filter { article in
            article.contentDeletedAt != nil ||
                policy.expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt) <= at
        }
        // Only the candidates' bodies are read (#250): every launch runs this, and most libraries have few or none.
        let snapshots = try snapshots(articleIDs: candidates.map(\.id))
        let withBody = Set(snapshots.filter { !$0.text.isEmpty }.map(\.articleID))
        let selected = candidates.filter { !$0.summary.isEmpty || withBody.contains($0.id) }
        let ids = Set(selected.map(\.id))
        let bodies = snapshots.filter { ids.contains($0.articleID) && !$0.text.isEmpty }
        let summaries = selected.filter { !$0.summary.isEmpty }
        return DeletionPreview(articleIDs: selected.map(\.id), bodyCount: bodies.count, summaryCount: summaries.count,
                               estimatedBytes: bodies.reduce(0) { $0 + $1.text.utf8.count } + summaries.reduce(0) { $0 + $1.summary.utf8.count })
    }
    /// The snapshots of these articles, fetched by ID in groups so one query never holds too many values.
    private func snapshots(articleIDs: [UUID]) throws -> [ContentSnapshot] {
        var result: [ContentSnapshot] = []
        for start in stride(from: 0, to: articleIDs.count, by: 1_000) {
            let group = Array(articleIDs[start..<min(start + 1_000, articleIDs.count)])
            result += try context.fetch(FetchDescriptor<ContentSnapshot>(predicate: #Predicate { group.contains($0.articleID) }))
        }
        return result
    }
    public func applyRetention(days: Int, at: Date) throws {
        try reloadIfNeeded()
        guard RetentionPolicy.choices.contains(days) else { throw RetentionError.invalidDays }
        // Purge under both policies: extending retention must not revive already-expired bytes.
        let old = try previewDeletion(days: nil, at: at)
        let proposed = try previewDeletion(days: days, at: at)
        let settings = try context.fetch(FetchDescriptor<ReaderSettings>()).first!
        let changed = settings.retentionDays != days
        let removed = try removeContent(articleIDs: Array(Set(old.articleIDs + proposed.articleIDs)), at: at)
        settings.retentionDays = days
        guard changed || removed else { return }
        try save()
        try reload()
    }
    public func deleteContent(articleIDs: [UUID], at: Date) throws {
        try reloadIfNeeded()
        guard try removeContent(articleIDs: articleIDs, at: at) else { return }
        try save()
        try reload()
    }
    public func purgeExpired(at: Date) throws {
        let preview = try previewDeletion(days: nil, at: at)
        try deleteContent(articleIDs: preview.articleIDs, at: at)
    }
    public func availableContentExpiries(at: Date, articleIDs: [UUID]? = nil) throws -> [UUID: Date] {
        try reloadIfNeeded()
        var values: [UUID: Date] = [:]
        let policy = RetentionPolicy(days: retentionDays)
        let selected = articleIDs.map { ids in ids.compactMap { article(id: $0) } } ?? articles
        for article in selected where isContentAvailable(article, at: at) {
            if try content(articleID: article.id, at: at) != nil {
                values[article.id] = policy.expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt)
            }
        }
        return values
    }
    @discardableResult func removeContent(articleIDs: [UUID], at: Date) throws -> Bool {
        try reloadIfNeeded()
        let ids = Set(articleIDs)
        let selected = articles.filter { ids.contains($0.id) }
        let snapshots = try context.fetch(FetchDescriptor<ContentSnapshot>())
        var changed = false
        for article in selected {
            if article.contentDeletedAt == nil || !article.summary.isEmpty || article.imageURL != nil {
                article.contentDeletedAt = article.contentDeletedAt ?? at
                article.summary = ""; article.imageURL = nil; changed = true
            }
        }
        for snapshot in snapshots where ids.contains(snapshot.articleID) {
            context.delete(snapshot); changed = true
        }
        return changed
    }
}
