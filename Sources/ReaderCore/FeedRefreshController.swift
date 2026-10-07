import Foundation
import Observation

@Observable @MainActor public final class FeedRefreshController {
    public private(set) var refreshing = false
    public private(set) var errors: [UUID: String] = [:]
    private let store: ReaderStore
    private let client: FeedClient
    public init(store: ReaderStore, client: FeedClient = FeedClient()) { self.store = store; self.client = client }
    private struct Request: Sendable { let id: UUID; let url: URL; let etag: String?; let modified: String? }
    public func refresh(feedIDs: [UUID]? = nil, at: Date = .now) async {
        guard !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        let requested = feedIDs.map(Set.init)
        let feeds = store.feeds.compactMap { feed -> Request? in
            guard requested == nil || requested!.contains(feed.id), let source = feed.sourceURL,
                  let url = ArticleURL.validated(source) else { return nil }
            return Request(id: feed.id, url: url, etag: feed.etag, modified: feed.lastModified)
        }
        await withTaskGroup(of: (Request, Result<FeedFetchResult, any Error>).self) { group in
            var iterator = feeds.makeIterator()
            func enqueue(_ request: Request) {
                let client = self.client
                group.addTask { (request, await Result { try await client.fetch(url: request.url, etag: request.etag, lastModified: request.modified) }) }
            }
            for _ in 0..<3 { if let request = iterator.next() { enqueue(request) } }
            while let (request, result) = await group.next() {
                if !Task.isCancelled, let feed = store.feeds.first(where: { $0.id == request.id && $0.sourceURL == request.url.absoluteString }) {
                    do {
                        try store.applyRefresh(result.get(), to: feed, at: at)
                        errors[feed.id] = nil
                    } catch { errors[feed.id] = error.localizedDescription }
                }
                if !Task.isCancelled, let next = iterator.next() { enqueue(next) }
            }
        }
        errors = errors.filter { id, _ in store.feeds.contains { $0.id == id } }
    }
}

private extension Result where Failure == any Error {
    init(_ body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}

extension ReaderStore {
    public func applyRefresh(_ result: FeedFetchResult, to feed: Feed, at: Date) throws {
        guard let feed = self.feed(id: feed.id) else { return }
        switch result {
        case .notModified: break
        case .modified(let parsed, let etag, let modified):
            guard parsed.sourceURL.absoluteString == feed.sourceURL else { return }
            _ = try importFeed(parsed, receivedAt: at)
            feed.etag = etag; feed.lastModified = modified
        }
        try recordFetch(feed, etag: feed.etag, lastModified: feed.lastModified, at: at)
    }
    public func recordFetch(_ feed: Feed, etag: String?, lastModified: String?, at: Date) throws {
        guard let feed = self.feed(id: feed.id) else { return }
        feed.etag = etag; feed.lastModified = lastModified; feed.lastFetchedAt = at
        try save(); try reload()
    }
}
