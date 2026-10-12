import Foundation

/// What to tell the person after an OPML file was read (decision 0039).
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
                return OPMLImportReport(title: "OPMLを取り込みました",
                                        message: "\(result.addedFeedIDs.count)件の購読を追加しましたが、一覧を更新できませんでした。アプリを開き直してください。", addedFeedIDs: [])
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

    static func report(added: [UUID], alreadySubscribed: Int, unusable: Int, upgraded: Int = 0) -> OPMLImportReport {
        var left: [String] = []
        if alreadySubscribed > 0 { left.append("すでに購読している\(alreadySubscribed)件") }
        if unusable > 0 { left.append("読めないアドレス\(unusable)件") }
        let notTaken = left.isEmpty ? nil : "取り込まなかったもの：" + left.joined(separator: "、") + "。"
        let message: String
        if !added.isEmpty {
            let upgradedNote = upgraded > 0 ? "http:// の\(upgraded)件は、https:// に変えて取り込みました。" : nil
            message = (["\(added.count)件の購読を追加しました。"] + [notTaken, upgradedNote].compactMap { $0 } + ["記事は、これから順に届きます。"]).joined(separator: "\n")
        } else if let notTaken {
            message = "新しい購読はありませんでした。\n" + notTaken
        } else {
            message = "このファイルに購読は見つかりませんでした。"
        }
        return OPMLImportReport(title: "OPMLを取り込みました", message: message, addedFeedIDs: added)
    }
}
