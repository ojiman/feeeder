import Foundation
import Observation

@Observable @MainActor public final class ArticleLoadingController {
    public private(set) var displayed: ArticleContent?
    public private(set) var availableUpdate: ArticleContent?
    public private(set) var loading = false
    public private(set) var error: String?
    private var state = ArticleLoadingState()
    private let store: ReaderStore
    private let fetcher: ArticleFetcher
    @ObservationIgnored private let now: @MainActor () -> Date
    public init(store: ReaderStore, fetcher: ArticleFetcher = ArticleFetcher(), now: @escaping @MainActor () -> Date = { .now }) {
        self.store = store; self.fetcher = fetcher; self.now = now
    }
    public func clear() { state = ArticleLoadingState(); displayed = nil; availableUpdate = nil; loading = false }
    public func load(articleID: UUID, refresh: Bool = false) async {
        let generation = state.begin(articleID: articleID)
        error = nil; availableUpdate = nil
        do { displayed = try store.content(articleID: articleID, at: now()) } catch { self.error = error.localizedDescription; displayed = nil }
        guard refresh || displayed?.coverage != .extracted,
              let article = store.articles.first(where: { $0.id == articleID }), store.isContentAvailable(article, at: now()),
              let url = article.originalURL.flatMap({ ArticleURL.validated($0) }) else { loading = false; return }
        loading = true
        let result = await fetcher.fetch(url: url)
        guard !Task.isCancelled, state.accept(articleID: articleID, generation: generation) else { return }
        loading = false
        guard let result else {
            if refresh { error = displayed == nil ? "本文を取得できませんでした。" : "本文を再取得できませんでした。保存済み本文を表示しています。" }
            return
        }
        do {
            try store.saveExtractedContent(articleID: articleID, result: result, at: now())
            refreshCachedContent()
        } catch { self.error = error.localizedDescription }
    }
    public func recordInteraction(articleID: UUID) { state.recordInteraction(articleID: articleID) }
    public func refreshCachedContent() {
        guard let id = state.selectedArticleID else { return }
        do {
            guard let latest = try store.content(articleID: id, at: now()) else { displayed = nil; availableUpdate = nil; return }
            // Check using the active generation without resetting its interaction history.
            if state.mayReplaceCurrentDisplay { displayed = latest; availableUpdate = nil }
            else if displayed != latest { availableUpdate = latest }
        } catch { self.error = error.localizedDescription }
    }
    public func applyAvailableUpdate() throws {
        guard let id = state.selectedArticleID, availableUpdate?.articleID == id else { return }
        displayed = try store.content(articleID: id, at: now()); availableUpdate = nil
    }
}
