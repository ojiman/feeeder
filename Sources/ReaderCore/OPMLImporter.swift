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
            return Self.report(added: result.addedFeedIDs, alreadySubscribed: result.alreadySubscribed + document.repeated,
                               unusable: document.skipped, fileHadFeeds: !document.feeds.isEmpty || document.skipped > 0)
        } catch {
            return OPMLImportReport(title: "OPMLを取り込めませんでした", message: error.localizedDescription, addedFeedIDs: [])
        }
    }

    /// The new subscriptions have no articles yet. A refresh that is already running does not take them, so wait for it first.
    public func fetchArticles(of ids: [UUID], using refresh: FeedRefreshController) async {
        while refresh.refreshing { do { try await Task.sleep(for: .milliseconds(500)) } catch { return } }
        await refresh.refresh(feedIDs: ids)
    }

    nonisolated static func read(_ url: URL) throws -> OPMLDocument {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= OPMLParser.maximumBytes else { throw OPMLError.tooLarge }
        return try OPMLParser.parse(Data(contentsOf: url))
    }

    static func report(added: [UUID], alreadySubscribed: Int, unusable: Int, fileHadFeeds: Bool) -> OPMLImportReport {
        var left: [String] = []
        if alreadySubscribed > 0 { left.append("すでに購読している\(alreadySubscribed)件") }
        if unusable > 0 { left.append("読めないアドレス\(unusable)件") }
        let notTaken = left.isEmpty ? nil : "取り込まなかったもの：" + left.joined(separator: "、") + "。"
        let message: String
        if !added.isEmpty {
            message = (["\(added.count)件の購読を追加しました。"] + [notTaken].compactMap { $0 } + ["記事は、これから順に届きます。"]).joined(separator: "\n")
        } else if let notTaken {
            message = "新しい購読はありませんでした。\n" + notTaken
        } else {
            message = "このファイルに購読は見つかりませんでした。"
        }
        return OPMLImportReport(title: "OPMLを取り込みました", message: message, addedFeedIDs: added)
    }
}
