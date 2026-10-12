import Foundation
import Observation

/// File ▸ 「OPMLを取り込む…」 from start to end (decision 0041): choose a file, add its subscriptions at once, keep the
/// report for the person to read, and fetch the new subscriptions' articles in the background. The file panel is injected.
@Observable @MainActor public final class OPMLImportFlow {
    /// What to tell the person; nil once they closed it.
    public private(set) var report: OPMLImportReport?
    /// True while the file panel is open: a second request is ignored instead of opening another panel.
    public private(set) var choosing = false
    private let importer: OPMLImporter
    private let refresh: FeedRefreshController
    private let chooseFile: @MainActor () async -> URL?

    public init(store: ReaderStore, refresh: FeedRefreshController, chooseFile: @escaping @MainActor () async -> URL?) {
        importer = OPMLImporter(store: store); self.refresh = refresh; self.chooseFile = chooseFile
    }

    public func start() async {
        guard !choosing else { return }
        choosing = true
        let url = await chooseFile()
        choosing = false
        guard let url else { return }
        let result = await importer.importFile(at: url)
        report = result
        if !result.addedFeedIDs.isEmpty { await importer.fetchArticles(of: result.addedFeedIDs, using: refresh) }
    }

    public func dismissReport() { report = nil }
}
