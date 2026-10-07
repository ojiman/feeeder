import Foundation

extension ReaderStore {
    public func folderArticleIDs(folder: String, keeping: UUID?) -> [UUID] {
        _ = feeds
        let values = folderIndex[folder] ?? []
        guard let keeping, !values.contains(keeping), article(id: keeping) != nil else { return values }
        let members = Set(values)
        return articleIDs.filter { members.contains($0) || $0 == keeping }
    }
    public func folderUnreadCount(folder: String) -> Int { folderUnreadCounts[folder] ?? 0 }
    public func moveFeed(id: UUID, toFolder: String) throws {
        try reloadIfNeeded()
        guard let feed = feed(id: id) else { return }
        let name = toFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard feed.folder != name else { return }
        feed.folder = name; try save(); try reload()
    }
    public func renameFolder(from: String, to: String) throws {
        try reloadIfNeeded()
        let source = from.trimmingCharacters(in: .whitespacesAndNewlines), target = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source != target else { return }
        for feed in feeds where feed.folder == source { feed.folder = target }
        try save(); try reload()
    }
}
