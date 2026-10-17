import Foundation

/// What to tell the person after an OPML file was read (decision 0041).
public struct OPMLImportReport: Equatable, Sendable {
    public let title: String
    public let message: String
    /// The subscriptions that were created; the app fetches their articles next.
    public let addedFeedIDs: [UUID]
}

/// Reads an OPML file and adds its subscriptions. The file is read and parsed off the main actor; the library is changed in one save.
@MainActor public struct OPMLImporter {
    private let store: ReaderStore
    public init(store: ReaderStore) { self.store = store }

    public func importFile(at url: URL) async -> OPMLImportReport {
        do {
            let document = try await Task.detached(priority: .userInitiated) { try Self.read(url) }.value
            let result = try store.importSubscriptions(document.feeds)
            if result.listRefreshFailed {
                // Saved, so it is not a failure; the new rows show after the list loads again.
                return OPMLImportReport(title: "\(result.addedFeedIDs.count)件の購読を追加しました",
                                        message: "一覧を更新できませんでした。アプリを開き直してください。", addedFeedIDs: [])
            }
            return Self.report(added: result.addedFeedIDs, alreadySubscribed: result.alreadySubscribed, unusable: document.skipped + result.rejected, upgraded: document.upgraded)
        } catch {
            return OPMLImportReport(title: "OPMLを取り込めませんでした", message: error.localizedDescription, addedFeedIDs: [])
        }
    }

    /// The new subscriptions have no articles yet. A refresh that is already running does not take them, so wait for it first.
    public func fetchArticles(of ids: [UUID], using refresh: FeedRefreshController) async {
        while refresh.refreshing { do { try await Task.sleep(for: .milliseconds(500)) } catch { return } }
        await refresh.refresh(feedIDs: ids)
    }

    /// Reads at most the limit (and one byte more, to see that the file is too big) from a regular file. The file is opened without
    /// waiting, and a pipe, a device or a folder is refused, so a strange file cannot hold the app or fill its memory.
    nonisolated static func read(_ url: URL) throws -> OPMLDocument {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK)
        guard descriptor >= 0 else { throw OPMLError.unreadable }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { throw OPMLError.unreadable }
        let data = try handle.read(upToCount: OPMLParser.maximumBytes + 1) ?? Data()
        return try OPMLParser.parse(data)
    }

    /// The result is the title; the message is a short list of what was not plain success, one line each, a count of zero left out
    /// (HIG: a short title, and a message only when it helps). The https count is not a part of the others: it counts the addresses changed.
    static func report(added: [UUID], alreadySubscribed: Int, unusable: Int, upgraded: Int = 0) -> OPMLImportReport {
        let counts = [("登録済み", alreadySubscribed), ("通信安全化", upgraded), ("失敗", unusable)]
        let lines = counts.filter { $0.1 > 0 }.map { "・\($0.0): \($0.1)件" }
        let left = alreadySubscribed + unusable
        let title: String
        if !added.isEmpty { title = "\(added.count)件の購読を追加しました" }
        else if left > 0 { title = "新しい購読はありませんでした" }
        else { title = "このファイルに購読は見つかりませんでした" }
        return OPMLImportReport(title: title, message: lines.joined(separator: "\n"), addedFeedIDs: added)
    }
}
