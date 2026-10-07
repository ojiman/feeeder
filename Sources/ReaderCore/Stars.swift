import Foundation

extension ReaderStore {
    public func setStar(articleID: UUID, isStarred: Bool, at: Date) throws {
        try reloadIfNeeded()
        guard let article = article(id: articleID), (article.starredAt != nil) != isStarred else { return }
        article.starredAt = isStarred ? at : nil
        try save()
        refreshStarIndex()
    }

    public func starredArticleIDs(keeping: UUID?) -> [UUID] {
        _ = starCount
        return articleIDs.filter { starredIDs.contains($0) || $0 == keeping }
    }
}
